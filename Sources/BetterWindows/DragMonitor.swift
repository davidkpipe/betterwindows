import AppKit
import Carbon.HIToolbox

/// Listen-only CGEvent tap for drag-relevant events: left mouse
/// down/drag/up and the Esc key. Creation requires Accessibility.
final class DragMonitor {
    enum Event {
        case down(CGPoint)
        case moved(CGPoint)
        case up(CGPoint)
        case escape
    }

    private let handler: (Event) -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(handler: @escaping (Event) -> Void) {
        self.handler = handler
    }

    deinit {
        stop()
    }

    /// Creates and enables the tap. False when the tap cannot be created,
    /// usually because Accessibility permission is missing.
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                Unmanaged<DragMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    .handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
    }

    /// Re-enables the tap if macOS silently disabled it (sleep/wake can do
    /// this without delivering a tapDisabled event). No-op when healthy.
    func reassert() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            handler(.down(event.location))
        case .leftMouseDragged:
            handler(.moved(event.location))
        case .leftMouseUp:
            handler(.up(event.location))
        case .keyDown:
            if event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape) {
                handler(.escape)
            }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables taps it thinks are stalling; recover.
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        default:
            break
        }
    }
}
