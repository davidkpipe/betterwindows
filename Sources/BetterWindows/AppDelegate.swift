import AppKit
import BetterWindowsCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        let enabledMenuItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)
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
        refreshEnabledState()
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        settings.isEnabled.toggle()
        refreshEnabledState()
    }

    private func refreshEnabledState() {
        enabledMenuItem?.state = settings.isEnabled ? .on : .off
    }
}
