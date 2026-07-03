import AppKit
import BetterWindowsCore

/// The settings window: a shortcut recorder per snap action, the drag-snap
/// toggle, and launch at login.
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let hotkeyStore: HotkeyStore
    private var loginItemCheckbox: NSButton?
    private var loginNoteLabel: NSTextField?

    /// Fired after the switcher toggle changes, so the app can start or
    /// stop the Option-Tab tap immediately.
    var onSwitcherToggle: (() -> Void)?

    init(settings: AppSettings, hotkeyStore: HotkeyStore) {
        self.settings = settings
        self.hotkeyStore = hotkeyStore
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BetterWindows Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        refreshLoginItemUI()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Layout

    private func buildContent() {
        var rows: [[NSView]] = []
        for action in SnapAction.allCases {
            let label = NSTextField(labelWithString: action.displayName)
            let recorder = ShortcutRecorderButton()
            recorder.display(binding: hotkeyStore.binding(for: action))
            recorder.onRecord = { [weak self] binding in
                self?.hotkeyStore.assign(binding, to: action) ?? .assigned
            }
            recorder.translatesAutoresizingMaskIntoConstraints = false
            recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
            rows.append([label, recorder])
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing

        let dragCheckbox = NSButton(
            checkboxWithTitle: "Snap when dragging to screen edges",
            target: self,
            action: #selector(toggleDragSnapping(_:))
        )
        dragCheckbox.state = settings.isDragSnappingEnabled ? .on : .off

        let switcherCheckbox = NSButton(
            checkboxWithTitle: "Option-Tab window switcher",
            target: self,
            action: #selector(toggleSwitcher(_:))
        )
        switcherCheckbox.state = settings.isSwitcherEnabled ? .on : .off

        let loginCheckbox = NSButton(
            checkboxWithTitle: "Launch at login",
            target: self,
            action: #selector(toggleLaunchAtLogin(_:))
        )
        loginItemCheckbox = loginCheckbox

        let loginNote = NSTextField(wrappingLabelWithString: "")
        loginNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        loginNote.textColor = .secondaryLabelColor
        loginNote.preferredMaxLayoutWidth = 380
        loginNoteLabel = loginNote

        let stack = NSStackView(views: [
            sectionLabel("Shortcuts"),
            grid,
            sectionLabel("Behavior"),
            dragCheckbox,
            switcherCheckbox,
            loginCheckbox,
            loginNote,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(20, after: grid)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        window?.contentView = stack
        window?.setContentSize(stack.fittingSize)
        window?.center()
        refreshLoginItemUI()
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    // MARK: Actions

    @objc private func toggleDragSnapping(_ sender: NSButton) {
        settings.isDragSnappingEnabled = sender.state == .on
    }

    @objc private func toggleSwitcher(_ sender: NSButton) {
        settings.isSwitcherEnabled = sender.state == .on
        onSwitcherToggle?()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            try LoginItem.setEnabled(sender.state == .on)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update launch at login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshLoginItemUI()
    }

    private func refreshLoginItemUI() {
        switch LoginItem.state {
        case .enabled:
            loginItemCheckbox?.isEnabled = true
            loginItemCheckbox?.state = .on
            loginNoteLabel?.stringValue = ""
        case .disabled:
            loginItemCheckbox?.isEnabled = true
            loginItemCheckbox?.state = .off
            loginNoteLabel?.stringValue = ""
        case .unavailable(let reason):
            loginItemCheckbox?.isEnabled = false
            loginItemCheckbox?.state = .off
            loginNoteLabel?.stringValue = reason
        }
    }
}
