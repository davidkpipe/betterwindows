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
    private let thumbnails = ThumbnailProvider()

    private var session: SwitcherSession?
    private var entries: [SwitcherEntry] = []
    private var grid: SwitcherGrid?
    /// Where the mouse sat when the panel appeared: hover only moves the
    /// selection after the mouse actually moves, so a panel materializing
    /// under a stationary cursor cannot hijack the initial selection.
    private var hoverArmLocation: CGPoint?

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
        tap.onMove = { [weak self] direction in self?.moveSelection(toward: direction) }
        tap.onCommit = { [weak self] in self?.commit() }
        tap.onCancel = { [weak self] in self?.cancel() }

        panel.onHoverIndex = { [weak self] index in self?.hoverSelect(index) }
        panel.onClickIndex = { [weak self] index in self?.activateByClick(index) }
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

    /// Display layout changed or the machine woke: an open panel's geometry
    /// is stale, and macOS may have silently disabled the tap. Dismiss the
    /// former, re-assert the latter.
    func handleSystemStateChange() {
        if session != nil {
            tap.endSession()
            cancel()
        }
        tap.reassert()
        applyEnabledState()
    }

    // MARK: Session

    private func begin() -> Bool {
        var snapshot = WindowEnumerator.currentSpaceWindows()
        model.prune(keeping: snapshot.map(\.key))
        snapshot = model.ordered(snapshot) { $0.key }
        guard let newSession = SwitcherSession(count: snapshot.count) else { return false }

        entries = snapshot
        session = newSession
        hoverArmLocation = NSEvent.mouseLocation

        // Cached thumbnails are dropped for windows that no longer exist.
        let liveKeys = entries.map(\.key)
        thumbnails.prune(keeping: liveKeys)

        if ThumbnailProvider.isAvailable() {
            // The panel appears immediately with the previous invocation's
            // captures (or app icons) standing in; fresh captures fill in
            // as they complete.
            var placeholders: [WindowKey: NSImage] = [:]
            for key in liveKeys {
                placeholders[key] = thumbnails.cachedImage(for: key)
            }
            panel.show(
                entries: entries,
                selectedIndex: newSession.selectedIndex,
                thumbnails: placeholders,
                footnote: nil
            )
            thumbnails.refresh(entries: entries) { [weak self] key, image in
                guard let self, self.session != nil else { return }
                self.panel.setThumbnail(forKey: key, image: image)
            }
        } else {
            panel.show(
                entries: entries,
                selectedIndex: newSession.selectedIndex,
                thumbnails: nil,
                footnote: "Window previews need Screen Recording — see Setup Guide in the menu"
            )
        }
        // The panel just laid the grid out; mirror its geometry for arrows.
        grid = SwitcherGrid(count: entries.count, maxColumns: panel.columns)
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

    private func moveSelection(toward direction: SwitcherTap.MoveDirection) {
        guard let grid, let session else { return }
        let current = session.selectedIndex
        let next: Int
        switch direction {
        case .left: next = grid.left(of: current)
        case .right: next = grid.right(of: current)
        case .up: next = grid.up(of: current)
        case .down: next = grid.down(of: current)
        }
        select(next)
    }

    private func select(_ index: Int) {
        guard var session else { return }
        session.select(index)
        self.session = session
        panel.updateSelection(session.selectedIndex)
    }

    private func hoverSelect(_ index: Int) {
        guard session != nil else { return }
        if let arm = hoverArmLocation {
            let mouse = NSEvent.mouseLocation
            guard hypot(mouse.x - arm.x, mouse.y - arm.y) > 3 else { return }
            hoverArmLocation = nil
        }
        select(index)
    }

    /// A thumbnail click: activates that window immediately, exactly like
    /// releasing Option on it. The tap forgets the session so the eventual
    /// real Option release passes through as a plain flags change.
    private func activateByClick(_ index: Int) {
        guard session != nil, entries.indices.contains(index) else { return }
        let entry = entries[index]
        tap.endSession()
        clearSession()
        activate(entry)
    }

    private func commit() {
        defer { clearSession() }
        guard let session, entries.indices.contains(session.selectedIndex) else { return }
        activate(entries[session.selectedIndex])
    }

    private func cancel() {
        clearSession()
    }

    private func clearSession() {
        session = nil
        entries = []
        grid = nil
        hoverArmLocation = nil
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
