import AppKit
import ApplicationServices

/// The only module allowed to touch the Accessibility API for window control.
///
/// Frame writes follow the PRD's reliability protocol: the app-level
/// "AXEnhancedUserInterface" setting is switched off for the duration of a
/// write (some frameworks reinterpret frame changes while it is on), and
/// every write is verified against the requested frame and retried before
/// giving up.
enum WindowControl {
    enum Failure: Error {
        case noFocusedWindow
    }

    private static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface"
    private static let maxWriteAttempts = 3
    /// Writes within this distance of the target (per edge, in points) count
    /// as applied — some apps round frames to whole pixels.
    private static let verifyTolerance: CGFloat = 1.0

    // MARK: Permission

    static func isTrusted(promptIfNeeded: Bool = false) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Focused window

    /// The focused window of the frontmost app, plus the app's own AX element
    /// (required to toggle the enhanced-user-interface setting around writes).
    static func focusedWindow() throws -> (window: AXUIElement, app: AXUIElement) {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            throw Failure.noFocusedWindow
        }
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        var ref: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref)
        guard status == .success, let raw = ref, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            throw Failure.noFocusedWindow
        }
        return (raw as! AXUIElement, app)
    }

    // MARK: Frames

    /// The window's frame in Accessibility/CG coordinates (top-left origin).
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointValue(of: window, attribute: kAXPositionAttribute),
              let size = sizeValue(of: window, attribute: kAXSizeAttribute)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    /// Writes `target` (Accessibility/CG coordinates) to the window,
    /// verifying and retrying until it sticks. Returns whether the final
    /// frame matches the target.
    @discardableResult
    static func setFrame(_ target: CGRect, window: AXUIElement, app: AXUIElement) -> Bool {
        let enhancedWasOn = boolValue(of: app, attribute: enhancedUserInterfaceAttribute) ?? false
        if enhancedWasOn {
            setBoolValue(false, of: app, attribute: enhancedUserInterfaceAttribute)
        }
        defer {
            if enhancedWasOn {
                setBoolValue(true, of: app, attribute: enhancedUserInterfaceAttribute)
            }
        }

        for attempt in 1 ... maxWriteAttempts {
            // Apps can clamp a move while the window is too large for the
            // destination, so retries shrink the window first.
            if attempt > 1 {
                write(size: target.size, to: window)
            }
            write(position: target.origin, to: window)
            write(size: target.size, to: window)

            if let current = frame(of: window), matches(current, target) {
                return true
            }
        }
        guard let final = frame(of: window) else { return false }
        return matches(final, target)
    }

    private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= verifyTolerance
            && abs(a.minY - b.minY) <= verifyTolerance
            && abs(a.width - b.width) <= verifyTolerance
            && abs(a.height - b.height) <= verifyTolerance
    }

    // MARK: AX plumbing

    private static func write(position: CGPoint, to window: AXUIElement) {
        var point = position
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private static func write(size: CGSize, to window: AXUIElement) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    private static func copyAXValue(of element: AXUIElement, attribute: String) -> AXValue? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let raw = ref, CFGetTypeID(raw) == AXValueGetTypeID()
        else {
            return nil
        }
        return (raw as! AXValue)
    }

    private static func pointValue(of element: AXUIElement, attribute: String) -> CGPoint? {
        guard let value = copyAXValue(of: element, attribute: attribute) else { return nil }
        var out = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &out) else { return nil }
        return out
    }

    private static func sizeValue(of element: AXUIElement, attribute: String) -> CGSize? {
        guard let value = copyAXValue(of: element, attribute: attribute) else { return nil }
        var out = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &out) else { return nil }
        return out
    }

    private static func boolValue(of element: AXUIElement, attribute: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let raw = ref, CFGetTypeID(raw) == CFBooleanGetTypeID()
        else {
            return nil
        }
        return CFBooleanGetValue((raw as! CFBoolean))
    }

    private static func setBoolValue(_ value: Bool, of element: AXUIElement, attribute: String) {
        AXUIElementSetAttributeValue(
            element,
            attribute as CFString,
            value ? kCFBooleanTrue : kCFBooleanFalse
        )
    }
}
