import AppKit
import Carbon.HIToolbox

/// The Option-Tab event tap. Active (not listen-only): while running,
/// Option-Tab and the keys of an open switcher session are swallowed so
/// they never reach the frontmost app. Stopping the tap restores native
/// Option-Tab behavior. Creation requires Accessibility.
final class SwitcherTap {
    enum MoveDirection {
        case left, right, up, down
    }

    /// Return true to begin a session (there was something to switch to).
    var onBegin: (() -> Bool)?
    var onAdvance: (() -> Void)?
    var onRetreat: (() -> Void)?
    var onMove: ((MoveDirection) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var sessionActive = false

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<SwitcherTap>.fromOpaque(refcon).takeUnretainedValue()
                .handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        runLoopSource = source
        return true
    }

    /// Ends the session without a commit or cancel callback — used when the
    /// coordinator already resolved it another way (a thumbnail click). The
    /// eventual Option release then passes through as a plain flags change.
    func endSession() {
        sessionActive = false
    }

    /// Re-enables the tap if macOS silently disabled it (sleep/wake can do
    /// this without delivering a tapDisabled event). No-op when healthy.
    func reassert() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stop() {
        if sessionActive {
            sessionActive = false
            onCancel?()
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    // MARK: Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // We may have missed the Option release; fail safe by cancelling.
            if sessionActive {
                sessionActive = false
                onCancel?()
            }
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        case .flagsChanged:
            if sessionActive, !event.flags.contains(.maskAlternate) {
                sessionActive = false
                onCommit?()
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Plain Option-Tab (Shift allowed for reverse). Command and Control
        // combinations stay native — Cmd-Tab is the system switcher.
        if keyCode == Int64(kVK_Tab),
           flags.contains(.maskAlternate),
           !flags.contains(.maskCommand),
           !flags.contains(.maskControl) {
            if sessionActive {
                flags.contains(.maskShift) ? onRetreat?() : onAdvance?()
            } else if onBegin?() == true {
                sessionActive = true
            }
            return nil // never let Option-Tab reach the frontmost app
        }

        if sessionActive, keyCode == Int64(kVK_Escape) {
            sessionActive = false
            onCancel?()
            return nil
        }

        if sessionActive, let direction = Self.arrowDirection(for: keyCode) {
            onMove?(direction)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        // Swallow the matching key-ups so apps never see half a keystroke.
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == Int64(kVK_Tab), event.flags.contains(.maskAlternate) {
            return nil
        }
        if sessionActive, keyCode == Int64(kVK_Escape) || Self.arrowDirection(for: keyCode) != nil {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private static func arrowDirection(for keyCode: Int64) -> MoveDirection? {
        switch keyCode {
        case Int64(kVK_LeftArrow): return .left
        case Int64(kVK_RightArrow): return .right
        case Int64(kVK_UpArrow): return .up
        case Int64(kVK_DownArrow): return .down
        default: return nil
        }
    }
}
