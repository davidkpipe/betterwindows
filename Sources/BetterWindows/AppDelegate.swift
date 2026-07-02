import AppKit
import BetterWindowsCore
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let hotkeys = HotkeyService()
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        registerHotkeys()
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
        // ⌃⌥Return: maximize the focused window.
        hotkeys.register(keyCode: kVK_Return, modifiers: controlKey | optionKey) { [weak self] in
            self?.maximizeFocusedWindow()
        }
    }

    private func maximizeFocusedWindow() {
        guard settings.isEnabled else { return }
        guard WindowControl.isTrusted() else {
            presentAccessibilityGuidance()
            return
        }
        guard let (window, app) = try? WindowControl.focusedWindow(),
              let windowFrame = WindowControl.frame(of: window),
              let target = maximizeTarget(forWindowAt: windowFrame)
        else {
            return
        }
        WindowControl.setFrame(target, window: window, app: app)
    }

    /// The visible frame (menu bar and Dock excluded), in AX coordinates, of
    /// the display the window currently occupies.
    private func maximizeTarget(forWindowAt windowFrame: CGRect) -> CGRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let screen = NSScreen.screens.first(where: { candidate in
            ScreenGeometry
                .cgRect(fromAppKit: candidate.frame, primaryScreenHeight: primaryHeight)
                .contains(center)
        }) ?? NSScreen.main ?? primary
        return ScreenGeometry.cgRect(
            fromAppKit: screen.visibleFrame,
            primaryScreenHeight: primaryHeight
        )
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
