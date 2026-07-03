import AppKit
import BetterWindowsCore

/// The switcher HUD: a non-activating panel with one cell per window (app
/// icon + window title), the selection highlighted, shown on the active
/// display. All keyboard handling lives in SwitcherTap — this panel never
/// becomes key and ignores the mouse.
final class SwitcherPanelController {
    private let panel: NSPanel
    private var cells: [NSView] = []

    private let inset: CGFloat = 12
    private let cellSpacing: CGFloat = 4
    private let cellHeight: CGFloat = 104
    private let maxCellWidth: CGFloat = 136
    private let minCellWidth: CGFloat = 72
    private let iconSide: CGFloat = 56

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
    }

    func show(entries: [SwitcherEntry], selectedIndex: Int) {
        guard !entries.isEmpty, let screen = targetScreen(for: entries.first) else { return }

        let count = CGFloat(entries.count)
        let available = screen.visibleFrame.width - 48 - 2 * inset - cellSpacing * (count - 1)
        let cellWidth = min(maxCellWidth, max(minCellWidth, available / count))
        let panelSize = CGSize(
            width: 2 * inset + count * cellWidth + (count - 1) * cellSpacing,
            height: 2 * inset + cellHeight
        )

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true

        cells = []
        for (index, entry) in entries.enumerated() {
            let cell = self.cell(for: entry, width: cellWidth)
            cell.setFrameOrigin(
                NSPoint(x: inset + CGFloat(index) * (cellWidth + cellSpacing), y: inset)
            )
            effect.addSubview(cell)
            cells.append(cell)
        }

        panel.setContentSize(panelSize)
        panel.contentView = effect
        updateSelection(selectedIndex)

        let visible = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - panelSize.width / 2,
                y: visible.midY - panelSize.height / 2
            )
        )
        panel.orderFrontRegardless()
    }

    func updateSelection(_ index: Int) {
        for (cellIndex, cell) in cells.enumerated() {
            cell.layer?.backgroundColor = cellIndex == index
                ? NSColor.selectedContentBackgroundColor.cgColor
                : nil
        }
    }

    func hide() {
        panel.orderOut(nil)
        cells = []
    }

    // MARK: Layout

    private func cell(for entry: SwitcherEntry, width: CGFloat) -> NSView {
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: width, height: cellHeight))
        cell.wantsLayer = true
        cell.layer?.cornerRadius = 10

        let icon = NSImageView(
            frame: NSRect(
                x: (width - iconSide) / 2,
                y: cellHeight - iconSide - 10,
                width: iconSide,
                height: iconSide
            )
        )
        icon.image = entry.icon
        icon.imageScaling = .scaleProportionallyUpOrDown
        // Minimized windows stay listed but read as inactive.
        icon.alphaValue = entry.isMinimized ? 0.4 : 1.0
        cell.addSubview(icon)

        let title = NSTextField(labelWithString: entry.title)
        title.font = .systemFont(ofSize: 11)
        title.alignment = .center
        title.lineBreakMode = .byTruncatingMiddle
        title.textColor = .labelColor
        title.frame = NSRect(x: 6, y: 10, width: width - 12, height: 30)
        title.maximumNumberOfLines = 2
        title.cell?.truncatesLastVisibleLine = true
        cell.addSubview(title)

        return cell
    }

    /// The active display: the one holding the most recently used window,
    /// falling back to the display under the mouse.
    private func targetScreen(for frontmost: SwitcherEntry?) -> NSScreen? {
        if let frontmost, let frame = WindowControl.frame(of: frontmost.window) {
            let appKit = ScreenGeometry.appKitRect(
                fromCG: frame,
                primaryScreenHeight: Displays.primaryScreenHeight
            )
            let center = CGPoint(x: appKit.midX, y: appKit.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
                return screen
            }
        }
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}
