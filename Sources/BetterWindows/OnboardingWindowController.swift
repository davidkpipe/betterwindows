import AppKit
import BetterWindowsCore

/// The onboarding window: one row per `OnboardingCatalog` item with a live
/// status indicator that flips as the user grants permissions in System
/// Settings — no relaunch — plus a deep link straight to the right pane.
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private static let contentWidth: CGFloat = 460

    private let settings: AppSettings

    /// Fires when a status poll finds Accessibility newly granted, so the
    /// app can start the drag tap immediately.
    var onAccessibilityGranted: (() -> Void)?

    private var statusLabels: [String: NSTextField] = [:]
    private var pollTimer: Timer?
    private var lastAccessibilityState = false

    init(settings: AppSettings) {
        self.settings = settings
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to BetterWindows"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        lastAccessibilityState = PermissionProbes.accessibilityGranted()
        refreshStatuses()
        startPolling()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Layout

    private func buildContent() {
        let header = NSTextField(wrappingLabelWithString: """
            BetterWindows works through two macOS permissions. Grant what \
            you need below — each indicator updates live, no relaunch needed.
            """)
        header.preferredMaxLayoutWidth = Self.contentWidth

        var views: [NSView] = [header]
        var fullWidthViews: [NSView] = [header]
        for item in OnboardingCatalog.items {
            let separator = NSBox()
            separator.boxType = .separator
            views.append(separator)
            fullWidthViews.append(separator)
            views.append(row(for: item))
        }

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        doneButton.keyEquivalent = "\r"
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.addView(doneButton, in: .trailing)
        views.append(footer)
        fullWidthViews.append(footer)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        for view in fullWidthViews {
            view.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        }

        window?.contentView = stack
        window?.setContentSize(stack.fittingSize)
        window?.center()
    }

    private func row(for item: OnboardingItem) -> NSView {
        let title = NSTextField(labelWithString: item.title)
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let status = NSTextField(labelWithString: "")
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabels[item.id] = status

        let titleRow = NSStackView(views: [title, status])
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .firstBaseline

        let detail = NSTextField(wrappingLabelWithString: item.detail)
        detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.preferredMaxLayoutWidth = Self.contentWidth

        let button = NSButton(
            title: buttonTitle(for: item),
            target: self,
            action: #selector(openPane(_:))
        )
        button.identifier = NSUserInterfaceItemIdentifier(item.id)

        let stack = NSStackView(views: [titleRow, detail, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        detail.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        return stack
    }

    private func buttonTitle(for item: OnboardingItem) -> String {
        item.id == OnboardingCatalog.nativeTiling.id
            ? "Open Desktop & Dock Settings"
            : "Open System Settings"
    }

    // MARK: Live status

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatuses()
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func refreshStatuses() {
        let accessibility = PermissionProbes.accessibilityGranted()
        setStatus(
            OnboardingCatalog.accessibility.id,
            text: accessibility ? "● Granted" : "○ Not granted",
            color: accessibility ? .systemGreen : .systemOrange
        )

        let screenRecording = PermissionProbes.screenRecordingGranted()
        setStatus(
            OnboardingCatalog.screenRecording.id,
            text: screenRecording ? "● Granted" : "○ Not granted",
            color: screenRecording ? .systemGreen : .systemOrange
        )

        switch PermissionProbes.nativeTilingEnabled() {
        case .some(true):
            setStatus(
                OnboardingCatalog.nativeTiling.id,
                text: "● On — may double-snap",
                color: .systemOrange
            )
        case .some(false):
            setStatus(OnboardingCatalog.nativeTiling.id, text: "● Off", color: .systemGreen)
        case .none:
            setStatus(
                OnboardingCatalog.nativeTiling.id,
                text: "Not present on this macOS",
                color: .secondaryLabelColor
            )
        }

        if accessibility && !lastAccessibilityState {
            onAccessibilityGranted?()
        }
        lastAccessibilityState = accessibility
    }

    private func setStatus(_ id: String, text: String, color: NSColor) {
        statusLabels[id]?.stringValue = text
        statusLabels[id]?.textColor = color
    }

    // MARK: Actions

    @objc private func openPane(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let item = OnboardingCatalog.items.first(where: { $0.id == id })
        else {
            return
        }
        // The system prompt registers the app in the Accessibility list, so
        // the user only has to flip the toggle on the pane we open next.
        if item.id == OnboardingCatalog.accessibility.id,
           !PermissionProbes.accessibilityGranted() {
            _ = WindowControl.isTrusted(promptIfNeeded: true)
        }
        if let url = URL(string: item.settingsURLString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func done(_ sender: NSButton) {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate()
        pollTimer = nil
        settings.hasCompletedOnboarding = true
    }
}
