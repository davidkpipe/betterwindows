import AppKit
import BetterWindowsCore
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let hotkeys = HotkeyService()
    private let snapTracker = SnapTracker()
    private var dragCoordinator: DragCoordinator?
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        registerHotkeys()

        let dragCoordinator = DragCoordinator(settings: settings)
        dragCoordinator.startIfPossible()
        self.dragCoordinator = dragCoordinator
    }

    // MARK: Status item

    private func setUpStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(
                systemSymbolName: "macwindow.on.rectangle",
                accessibilityDescription: "BetterWindows"
            ) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "BW"
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        let enabledMenuItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        let accessibilityMenuItem = NSMenuItem(
            title: "Grant Accessibility Access…",
            action: #selector(openAccessibilitySettings(_:)),
            keyEquivalent: ""
        )
        accessibilityMenuItem.target = self
        menu.addItem(accessibilityMenuItem)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit BetterWindows",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem.menu = menu

        self.statusItem = statusItem
        self.enabledMenuItem = enabledMenuItem
        self.accessibilityMenuItem = accessibilityMenuItem
        refreshMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }

    private func refreshMenuState() {
        enabledMenuItem?.state = settings.isEnabled ? .on : .off
        accessibilityMenuItem?.isHidden = WindowControl.isTrusted()
        // Retry the drag tap here so granting Accessibility takes effect
        // without a relaunch (full onboarding is a later slice).
        dragCoordinator?.startIfPossible()
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        settings.isEnabled.toggle()
        refreshMenuState()
    }

    @objc private func openAccessibilitySettings(_ sender: NSMenuItem) {
        openAccessibilityPane()
    }

    // MARK: Hotkeys

    private func registerHotkeys() {
        // Rectangle's idiom: ⌃⌥ + arrows for halves, Return to maximize,
        // U/I/J/K for quarters, C to center.
        let bindings: [(keyCode: Int, zone: SnapZone)] = [
            (kVK_LeftArrow, .leftHalf),
            (kVK_RightArrow, .rightHalf),
            (kVK_UpArrow, .topHalf),
            (kVK_DownArrow, .bottomHalf),
            (kVK_Return, .maximize),
            (kVK_ANSI_U, .topLeftQuarter),
            (kVK_ANSI_I, .topRightQuarter),
            (kVK_ANSI_J, .bottomLeftQuarter),
            (kVK_ANSI_K, .bottomRightQuarter),
            (kVK_ANSI_C, .center),
        ]
        for binding in bindings {
            hotkeys.register(keyCode: binding.keyCode, modifiers: controlKey | optionKey) { [weak self] in
                self?.snapFocusedWindow(to: binding.zone)
            }
        }

        // ⌃⌥⌫: restore the focused window to its pre-snap frame.
        hotkeys.register(keyCode: kVK_Delete, modifiers: controlKey | optionKey) { [weak self] in
            self?.restoreFocusedWindow()
        }
    }

    private func snapFocusedWindow(to zone: SnapZone) {
        guard settings.isEnabled else { return }
        guard WindowControl.isTrusted() else {
            presentAccessibilityGuidance()
            return
        }
        guard let (window, app, pid) = try? WindowControl.focusedWindow(),
              let windowFrame = WindowControl.frame(of: window),
              let visibleFrame = visibleFrameCG(forWindowAt: windowFrame)
        else {
            return
        }
        let target = SnapEngine.targetFrame(
            for: zone,
            visibleFrame: visibleFrame,
            windowFrame: windowFrame
        )
        snapTracker.noteSnap(of: window, pid: pid, preSnapFrame: windowFrame)
        WindowControl.setFrame(target, window: window, app: app)
    }

    private func restoreFocusedWindow() {
        guard settings.isEnabled else { return }
        guard WindowControl.isTrusted() else {
            presentAccessibilityGuidance()
            return
        }
        guard let (window, app, _) = try? WindowControl.focusedWindow(),
              let original = snapTracker.consumeRestoreFrame(of: window)
        else {
            return
        }
        WindowControl.setFrame(original, window: window, app: app)
    }

    /// The visible frame (menu bar and Dock excluded), in AX coordinates, of
    /// the display the window currently occupies.
    private func visibleFrameCG(forWindowAt windowFrame: CGRect) -> CGRect? {
        Displays.under(CGPoint(x: windowFrame.midX, y: windowFrame.midY))?.visibleFrame
    }

    // MARK: Accessibility permission

    private func presentAccessibilityGuidance() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "BetterWindows needs Accessibility access"
        alert.informativeText = """
            Moving and resizing windows uses the macOS Accessibility API. \
            Enable BetterWindows under System Settings > Privacy & Security > \
            Accessibility, then press the hotkey again.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilityPane()
        }
    }

    private func openAccessibilityPane() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: pane) {
            NSWorkspace.shared.open(url)
        }
    }
}
