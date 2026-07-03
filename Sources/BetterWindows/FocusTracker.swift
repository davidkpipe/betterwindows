import AppKit
import ApplicationServices

/// Feeds the switcher's MRU history: reports the focused window on every
/// app switch and, via one AX observer per app, every window-focus change
/// within an app.
final class FocusTracker {
    var onWindowFocused: ((AXUIElement) -> Void)?

    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var started = false

    deinit {
        stop()
    }

    /// Requires Accessibility; safe to call repeatedly.
    func start() {
        guard !started else { return }
        started = true

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let app = Self.application(of: note) else { return }
                self?.appActivated(app)
            }
        )
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let app = Self.application(of: note) else { return }
                self?.removeObserver(pid: app.processIdentifier)
            }
        )

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            observeFocusChanges(pid: app.processIdentifier)
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            appActivated(frontmost)
        }
    }

    func stop() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers = []
        for pid in Array(observers.keys) {
            removeObserver(pid: pid)
        }
        started = false
    }

    private static func application(of note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    private func appActivated(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        let pid = app.processIdentifier
        // Newly launched apps register here on their first activation —
        // their AX server may not exist yet at launch time.
        observeFocusChanges(pid: pid)

        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            WindowControl.appElement(pid: pid),
            kAXFocusedWindowAttribute as CFString,
            &ref
        ) == .success,
            let raw = ref, CFGetTypeID(raw) == AXUIElementGetTypeID() {
            onWindowFocused?(raw as! AXUIElement)
        }
    }

    private func observeFocusChanges(pid: pid_t) {
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, _, refcon in
            guard let refcon else { return }
            Unmanaged<FocusTracker>.fromOpaque(refcon).takeUnretainedValue()
                .onWindowFocused?(element)
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
            return
        }
        guard AXObserverAddNotification(
            observer,
            WindowControl.appElement(pid: pid),
            kAXFocusedWindowChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        ) == .success else {
            return
        }
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        observers[pid] = observer
    }

    private func removeObserver(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }
}
