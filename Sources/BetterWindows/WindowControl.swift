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
    /// (required to toggle the enhanced-user-interface setting around writes)
    /// and its process id (used to watch window lifetime).
    static func focusedWindow() throws -> (window: AXUIElement, app: AXUIElement, pid: pid_t) {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            throw Failure.noFocusedWindow
        }
        let pid = frontmost.processIdentifier
        let app = AXUIElementCreateApplication(pid)
        var ref: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref)
        guard status == .success, let raw = ref, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            throw Failure.noFocusedWindow
        }
        return (raw as! AXUIElement, app, pid)
    }

    /// The process id owning an AX element.
    static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    // MARK: Window under a point

    private static let systemWide = AXUIElementCreateSystemWide()

    /// The window under `point` (CG coordinates) and its frame, if any.
    static func window(at point: CGPoint) -> (window: AXUIElement, frame: CGRect)? {
        var hitRef: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(
            systemWide, Float(point.x), Float(point.y), &hitRef
        )
        guard status == .success, let hit = hitRef,
              let window = containingWindow(of: hit),
              let frame = frame(of: window)
        else {
            return nil
        }
        return (window, frame)
    }

    private static func containingWindow(of element: AXUIElement) -> AXUIElement? {
        if role(of: element) == kAXWindowRole { return element }

        // Most elements expose their window directly.
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &ref) == .success,
           let raw = ref, CFGetTypeID(raw) == AXUIElementGetTypeID() {
            return (raw as! AXUIElement)
        }

        // Fall back to walking the parent chain.
        var current = element
        for _ in 0 ..< 25 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let rawParent = parentRef, CFGetTypeID(rawParent) == AXUIElementGetTypeID()
            else {
                return nil
            }
            current = rawParent as! AXUIElement
            if role(of: current) == kAXWindowRole { return current }
        }
        return nil
    }

    private static func role(of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }

    private static func subrole(of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }

    // MARK: App windows (switcher)

    /// The app's AX element with a short messaging timeout, so talking to a
    /// hung app cannot stall the caller for the multi-second AX default.
    static func appElement(pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        return app
    }

    /// All standard windows of an app, minimized included. The AX API only
    /// surfaces windows on the current Space — exactly the switcher's scope.
    static func standardWindows(ofAppWithPid pid: pid_t) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement(pid: pid), kAXWindowsAttribute as CFString, &ref
        ) == .success,
            let raw = ref, CFGetTypeID(raw) == CFArrayGetTypeID(),
            let windows = raw as? [AXUIElement]
        else {
            return []
        }
        return windows.filter { subrole(of: $0) == kAXStandardWindowSubrole }
    }

    static func title(of window: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }

    static func isMinimized(_ window: AXUIElement) -> Bool {
        boolValue(of: window, attribute: kAXMinimizedAttribute as String) ?? false
    }

    static func setMinimized(_ minimized: Bool, window: AXUIElement) {
        setBoolValue(minimized, of: window, attribute: kAXMinimizedAttribute as String)
    }

    /// Brings the window to the front of its app and makes it the main
    /// window. App-level activation is the caller's job.
    static func raise(_ window: AXUIElement) {
        setBoolValue(true, of: window, attribute: kAXMainAttribute as String)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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
