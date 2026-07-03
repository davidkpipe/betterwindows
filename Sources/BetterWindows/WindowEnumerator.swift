import AppKit
import ApplicationServices

/// One switcher entry: a live window plus the metadata the panel renders.
/// Snapshotted fresh on every invocation so titles and minimized states are
/// never stale and closed windows vanish structurally.
struct SwitcherEntry {
    let key: WindowKey
    let window: AXUIElement
    let pid: pid_t
    let title: String
    let appName: String
    let icon: NSImage?
    let isMinimized: Bool
}

/// Builds the switcher's window snapshot: every standard window of every
/// regular app on the current Space, minimized included.
enum WindowEnumerator {
    static func currentSpaceWindows() -> [SwitcherEntry] {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        // Frontmost app first, so a fresh MRU history still opens with the
        // active window leading the list.
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPid }
            .sorted { $0.isActive && !$1.isActive }

        var entries: [SwitcherEntry] = []
        for app in apps {
            let pid = app.processIdentifier
            let appName = app.localizedName ?? "App"
            for window in WindowControl.standardWindows(ofAppWithPid: pid) {
                let title = WindowControl.title(of: window)
                    .flatMap { $0.isEmpty ? nil : $0 } ?? appName
                entries.append(
                    SwitcherEntry(
                        key: WindowKey(element: window),
                        window: window,
                        pid: pid,
                        title: title,
                        appName: appName,
                        icon: app.icon,
                        isMinimized: WindowControl.isMinimized(window)
                    )
                )
            }
        }
        return entries
    }
}
