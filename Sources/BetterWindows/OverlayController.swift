import AppKit
import BetterWindowsCore

/// The translucent zone preview: a borderless, non-activating panel that
/// ignores mouse events and never becomes key — the dragged window keeps
/// focus and the drag is never interrupted.
final class OverlayController {
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        let content = NSView()
        content.wantsLayer = true
        if let layer = content.layer {
            layer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            layer.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
            layer.borderWidth = 2
            layer.cornerRadius = 10
        }
        panel.contentView = content
    }

    /// Shows (or moves) the preview to `frame`, given in Accessibility/CG
    /// coordinates.
    func show(cgFrame: CGRect) {
        let appKitFrame = ScreenGeometry.appKitRect(
            fromCG: cgFrame,
            primaryScreenHeight: Displays.primaryScreenHeight
        )
        panel.setFrame(appKitFrame, display: true)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }
}
