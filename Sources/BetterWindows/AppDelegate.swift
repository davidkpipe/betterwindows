import AppKit
import BetterWindowsCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let hotkeys = HotkeyService()
    private let snapTracker = SnapTracker()
    private lazy var hotkeyStore = HotkeyStore(settings: settings)
    private var dragCoordinator: DragCoordinator?
    private var settingsWindowController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        hotkeyStore.onChange = { [weak self] in
            self?.applyHotkeys()
        }
        applyHotkeys()

        let dragCoordinator = DragCoordinator(settings: settings, snapTracker: snapTracker)
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

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    @objc private func openSettings(_ sender: NSMenuItem) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settings: settings,
                hotkeyStore: hotkeyStore
            )
        }
        settingsWindowController?.showWindow(nil)
    }

    // MARK: Hotkeys

    /// (Re)registers every action's current binding — called at launch and
    /// whenever a shortcut is re-recorded, so changes apply immediately.
    private func applyHotkeys() {
        hotkeys.unregisterAll()
        for action in SnapAction.allCases {
            guard let binding = hotkeyStore.binding(for: action) else { continue }
            hotkeys.register(keyCode: binding.keyCode, modifiers: binding.modifiers) { [weak self] in
                self?.perform(action)
            }
        }
    }

    private func perform(_ action: SnapAction) {
        if let zone = action.zone {
            snapFocusedWindow(to: zone)
        } else {
            restoreFocusedWindow()
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
