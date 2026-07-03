import AppKit
import BetterWindowsCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let hotkeys = HotkeyService()
    private let snapTracker = SnapTracker()
    private lazy var hotkeyStore = HotkeyStore(settings: settings)
    private var dragCoordinator: DragCoordinator?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        hotkeyStore.onChange = { [weak self] in
            self?.applyHotkeys()
        }
        applyHotkeys()

        let dragCoordinator = DragCoordinator(settings: settings, snapTracker: snapTracker)
        dragCoordinator.startIfPossible()
        self.dragCoordinator = dragCoordinator

        presentOnboardingIfNeeded()
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

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let setupItem = NSMenuItem(
            title: "Setup Guide…",
            action: #selector(openSetupGuide(_:)),
            keyEquivalent: ""
        )
        setupItem.target = self
        menu.addItem(setupItem)

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
        refreshMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }

    private func refreshMenuState() {
        enabledMenuItem?.state = settings.isEnabled ? .on : .off
        // Retry the drag tap here as a backstop, so granting Accessibility
        // takes effect without a relaunch even if onboarding never opened.
        dragCoordinator?.startIfPossible()
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        settings.isEnabled.toggle()
        refreshMenuState()
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

    @objc private func openSetupGuide(_ sender: NSMenuItem) {
        showOnboarding()
    }

    // MARK: Onboarding

    private func presentOnboardingIfNeeded() {
        let allGranted = PermissionProbes.accessibilityGranted()
            && PermissionProbes.screenRecordingGranted()
        guard OnboardingGate.shouldAutoPresent(
            hasCompletedOnboarding: settings.hasCompletedOnboarding,
            allPermissionsGranted: allGranted
        ) else {
            return
        }
        showOnboarding()
    }

    private func showOnboarding() {
        if onboardingWindowController == nil {
            let controller = OnboardingWindowController(settings: settings)
            controller.onAccessibilityGranted = { [weak self] in
                self?.dragCoordinator?.startIfPossible()
            }
            onboardingWindowController = controller
        }
        onboardingWindowController?.showWindow(nil)
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
            showOnboarding()
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
            showOnboarding()
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
}
