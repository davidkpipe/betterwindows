import AppKit

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate

// Menu-bar-only app: no Dock icon, no app menu.
app.setActivationPolicy(.accessory)
app.run()
