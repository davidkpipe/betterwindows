import AppKit
import BetterWindowsCore

/// The switcher HUD: a non-activating panel with one cell per window, the
/// selection highlighted, shown on the active display. With Screen
/// Recording granted the cells are live window thumbnails (app icon badge +
/// title); otherwise the icons + titles fallback with a hint to onboarding.
/// All keyboard handling lives in SwitcherTap — this panel never becomes
/// key and ignores the mouse.
final class SwitcherPanelController {
    private let panel: NSPanel
    private var cells: [NSView] = []
    private var keys: [WindowKey] = []
    private var thumbnailViews: [NSImageView] = []
    private var placeholderViews: [NSImageView] = []

    private struct Metrics {
        let cellWidth: CGFloat
        let cellHeight: CGFloat
        let thumbnailHeight: CGFloat // 0 in fallback mode
    }

    private let inset: CGFloat = 12
    private let cellSpacing: CGFloat = 4
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

    /// `thumbnails` nil renders the icons + titles fallback; non-nil renders
    /// thumbnail cells, using the given images as instant placeholders and
    /// leaving the rest to `setThumbnail` as captures land.
    func show(
        entries: [SwitcherEntry],
        selectedIndex: Int,
        thumbnails: [WindowKey: NSImage]?,
        footnote: String?
    ) {
        guard !entries.isEmpty, let screen = targetScreen(for: entries.first) else { return }

        let thumbnailMode = thumbnails != nil
        let count = CGFloat(entries.count)
        let maxCellWidth: CGFloat = thumbnailMode ? 228 : 136
        let minCellWidth: CGFloat = thumbnailMode ? 128 : 72
        let available = screen.visibleFrame.width - 48 - 2 * inset - cellSpacing * (count - 1)
        let metrics = Metrics(
            cellWidth: min(maxCellWidth, max(minCellWidth, available / count)),
            cellHeight: thumbnailMode ? 178 : 104,
            thumbnailHeight: thumbnailMode ? 132 : 0
        )
        let footnoteHeight: CGFloat = footnote == nil ? 0 : 22
        let panelSize = CGSize(
            width: 2 * inset + count * metrics.cellWidth + (count - 1) * cellSpacing,
            height: 2 * inset + metrics.cellHeight + footnoteHeight
        )

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true

        cells = []
        keys = entries.map(\.key)
        thumbnailViews = []
        placeholderViews = []
        for (index, entry) in entries.enumerated() {
            let cell = self.cell(
                for: entry,
                metrics: metrics,
                thumbnailMode: thumbnailMode,
                placeholder: thumbnails?[entry.key]
            )
            cell.setFrameOrigin(
                NSPoint(
                    x: inset + CGFloat(index) * (metrics.cellWidth + cellSpacing),
                    y: inset + footnoteHeight
                )
            )
            effect.addSubview(cell)
            cells.append(cell)
        }

        if let footnote {
            let label = NSTextField(labelWithString: footnote)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSRect(x: inset, y: 8, width: panelSize.width - 2 * inset, height: 16)
            effect.addSubview(label)
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

    /// Fills a freshly captured thumbnail into its cell — no-op if the
    /// panel has moved on to a different window set.
    func setThumbnail(forKey key: WindowKey, image: NSImage) {
        guard let index = keys.firstIndex(of: key),
              thumbnailViews.indices.contains(index)
        else { return }
        thumbnailViews[index].image = image
        placeholderViews[index].isHidden = true
    }

    func hide() {
        panel.orderOut(nil)
        cells = []
        keys = []
        thumbnailViews = []
        placeholderViews = []
    }

    // MARK: Layout

    private func cell(
        for entry: SwitcherEntry,
        metrics: Metrics,
        thumbnailMode: Bool,
        placeholder: NSImage?
    ) -> NSView {
        let cell = NSView(
            frame: NSRect(x: 0, y: 0, width: metrics.cellWidth, height: metrics.cellHeight)
        )
        cell.wantsLayer = true
        cell.layer?.cornerRadius = 10

        if thumbnailMode {
            addThumbnailContent(to: cell, entry: entry, metrics: metrics, placeholder: placeholder)
        } else {
            addIconContent(to: cell, entry: entry, metrics: metrics)
        }

        let title = NSTextField(labelWithString: entry.title)
        title.font = .systemFont(ofSize: 11)
        title.alignment = .center
        title.lineBreakMode = .byTruncatingMiddle
        title.textColor = .labelColor
        title.frame = NSRect(x: 6, y: 10, width: metrics.cellWidth - 12, height: 30)
        title.maximumNumberOfLines = 2
        title.cell?.truncatesLastVisibleLine = true
        cell.addSubview(title)

        return cell
    }

    /// Icons + titles fallback: the app icon is the hero.
    private func addIconContent(to cell: NSView, entry: SwitcherEntry, metrics: Metrics) {
        let icon = NSImageView(
            frame: NSRect(
                x: (metrics.cellWidth - iconSide) / 2,
                y: metrics.cellHeight - iconSide - 10,
                width: iconSide,
                height: iconSide
            )
        )
        icon.image = entry.icon
        icon.imageScaling = .scaleProportionallyUpOrDown
        // Minimized windows stay listed but read as inactive.
        icon.alphaValue = entry.isMinimized ? 0.4 : 1.0
        cell.addSubview(icon)
    }

    /// Thumbnail cell: capture on top, app icon badge overlaid, title below.
    /// Until a capture lands, a centered app icon stands in.
    private func addThumbnailContent(
        to cell: NSView,
        entry: SwitcherEntry,
        metrics: Metrics,
        placeholder: NSImage?
    ) {
        let thumbnailArea = NSRect(
            x: 8,
            y: metrics.cellHeight - metrics.thumbnailHeight - 8,
            width: metrics.cellWidth - 16,
            height: metrics.thumbnailHeight
        )

        let thumbnailView = NSImageView(frame: thumbnailArea)
        thumbnailView.imageScaling = .scaleProportionallyDown
        thumbnailView.image = placeholder
        thumbnailView.alphaValue = entry.isMinimized ? 0.7 : 1.0
        cell.addSubview(thumbnailView)

        let placeholderIcon = NSImageView(
            frame: NSRect(
                x: thumbnailArea.midX - iconSide / 2,
                y: thumbnailArea.midY - iconSide / 2,
                width: iconSide,
                height: iconSide
            )
        )
        placeholderIcon.image = entry.icon
        placeholderIcon.imageScaling = .scaleProportionallyUpOrDown
        placeholderIcon.alphaValue = entry.isMinimized ? 0.4 : 1.0
        placeholderIcon.isHidden = placeholder != nil
        cell.addSubview(placeholderIcon)

        let badgeSide: CGFloat = 28
        let badge = NSImageView(
            frame: NSRect(
                x: thumbnailArea.maxX - badgeSide - 2,
                y: thumbnailArea.minY - 6,
                width: badgeSide,
                height: badgeSide
            )
        )
        badge.image = entry.icon
        badge.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(badge)

        thumbnailViews.append(thumbnailView)
        placeholderViews.append(placeholderIcon)
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
