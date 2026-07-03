import AppKit
import ApplicationServices
import BetterWindowsCore

/// App-side owner of the restore ledger: keys it by AX window identity,
/// watches tracked windows for destruction, and drops all of an app's
/// entries when it terminates.
final class SnapTracker {
    private var ledger = RestoreLedger<WindowKey>()
    private var observers: [pid_t: AXObserver] = [:]
    private var trackedWindows: [pid_t: Set<WindowKey>] = [:]
    private var terminationObserver: NSObjectProtocol?

    init() {
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            else { return }
            self?.dropEntries(for: app.processIdentifier)
        }
    }

    deinit {
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        }
    }

    /// Records the window's pre-snap frame (first snap only) and starts
    /// watching the window so its entry dies with it.
    func noteSnap(of window: AXUIElement, pid: pid_t, preSnapFrame: CGRect) {
        let key = WindowKey(element: window)
        ledger.recordPreSnapFrame(preSnapFrame, for: key)
        watchDestruction(of: key, pid: pid)
    }

    /// The pre-snap frame to restore, consuming the entry. Nil when the
    /// window was never snapped.
    func consumeRestoreFrame(of window: AXUIElement) -> CGRect? {
        ledger.consumeRestoreFrame(for: WindowKey(element: window))
    }

    // MARK: Window lifetime

    private func watchDestruction(of key: WindowKey, pid: pid_t) {
        guard trackedWindows[pid]?.contains(key) != true else { return }

        if observers[pid] == nil {
            var observer: AXObserver?
            let callback: AXObserverCallback = { _, element, _, refcon in
                guard let refcon else { return }
                Unmanaged<SnapTracker>.fromOpaque(refcon).takeUnretainedValue()
                    .windowWasDestroyed(element)
            }
            guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
                return
            }
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            observers[pid] = observer
        }

        guard let observer = observers[pid] else { return }
        AXObserverAddNotification(
            observer,
            key.element,
            kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        trackedWindows[pid, default: []].insert(key)
    }

    private func windowWasDestroyed(_ element: AXUIElement) {
        let key = WindowKey(element: element)
        ledger.removeEntry(for: key)
        for pid in trackedWindows.keys {
            trackedWindows[pid]?.remove(key)
        }
    }

    private func dropEntries(for pid: pid_t) {
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        for key in trackedWindows.removeValue(forKey: pid) ?? [] {
            ledger.removeEntry(for: key)
        }
    }
}
