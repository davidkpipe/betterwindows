import AppKit
import BetterWindowsCore

/// Glue for the Option-Tab switcher: owns the MRU history, the event tap,
/// the focus tracker, and the panel; runs one switcher session at a time.
///
/// A session lives between the first Option-Tab and the Option release:
/// the window list is snapshotted once at session start, Tab/Shift-Tab move
/// the selection, releasing Option activates it, Esc abandons it.
final class SwitcherCoordinator {
    private let settings: AppSettings
    private var model = WindowListModel<WindowKey>()
    private let focusTracker = FocusTracker()
    private let tap = SwitcherTap()
    private let panel = SwitcherPanelController()

    private var session: SwitcherSession?
    private var entries: [SwitcherEntry] = []

    init(settings: AppSettings) {
        self.settings = settings

        focusTracker.onWindowFocused = { [weak self] window in
            // Only frontmost-app focus changes count as "the user used this
            // window" — background apps shuffling their own windows do not.
            guard let pid = WindowControl.pid(of: window),
                  pid == NSWorkspace.shared.frontmostApplication?.processIdentifier
            else { return }
            self?.model.noteFocused(WindowKey(element: window))
        }

        tap.onBegin = { [weak self] in self?.begin() ?? false }
        tap.onAdvance = { [weak self] in self?.moveSelection(by: 1) }
        tap.onRetreat = { [weak self] in self?.moveSelection(by: -1) }
        tap.onCommit = { [weak self] in self?.commit() }
        tap.onCancel = { [weak self] in self?.cancel() }
    }

    /// Starts or stops to match the settings and permission state; safe to
    /// call repeatedly (also used as a backstop from menu refresh).
    func applyEnabledState() {
        let wanted = settings.isEnabled && settings.isSwitcherEnabled && WindowControl.isTrusted()
        if wanted {
            focusTracker.start()
            tap.start()
        } else {
            tap.stop()
        }
    }

    // MARK: Session

    private func begin() -> Bool {
        var snapshot = WindowEnumerator.currentSpaceWindows()
        model.prune(keeping: snapshot.map(\.key))
        snapshot = model.ordered(snapshot) { $0.key }
        guard let newSession = SwitcherSession(count: snapshot.count) else { return false }

        entries = snapshot
        session = newSession
        panel.show(entries: entries, selectedIndex: newSession.selectedIndex)
        return true
    }

    private func moveSelection(by direction: Int) {
        guard var session else { return }
        if direction > 0 {
            session.advance()
        } else {
            session.retreat()
        }
        self.session = session
        panel.updateSelection(session.selectedIndex)
    }

    private func commit() {
        defer {
            session = nil
            entries = []
            panel.hide()
        }
        guard let session, entries.indices.contains(session.selectedIndex) else { return }
        activate(entries[session.selectedIndex])
    }

    private func cancel() {
        session = nil
        entries = []
        panel.hide()
    }

    private func activate(_ entry: SwitcherEntry) {
        if entry.isMinimized {
            WindowControl.setMinimized(false, window: entry.window)
        }
        WindowControl.raise(entry.window)
        NSRunningApplication(processIdentifier: entry.pid)?.activate(options: [])
        // Record immediately — the focus notification may race the next
        // switcher invocation.
        model.noteFocused(entry.key)
    }
}
