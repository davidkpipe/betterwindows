import AppKit
import BetterWindowsCore

/// Screen lookups in Accessibility/CG coordinates.
enum Displays {
    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Visible frames of every attached display, in CG space — the
    /// candidate homes when a restored frame's display is gone.
    static var allVisibleFrames: [CGRect] {
        let primaryHeight = primaryScreenHeight
        return NSScreen.screens.map {
            ScreenGeometry.cgRect(fromAppKit: $0.visibleFrame, primaryScreenHeight: primaryHeight)
        }
    }

    /// The display containing `point` (CG coordinates): its full frame and
    /// its visible frame, both in CG space. Falls back to the main display.
    static func under(_ point: CGPoint) -> (frame: CGRect, visibleFrame: CGRect)? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height
        let screen = NSScreen.screens.first(where: { candidate in
            ScreenGeometry
                .cgRect(fromAppKit: candidate.frame, primaryScreenHeight: primaryHeight)
                .contains(point)
        }) ?? NSScreen.main ?? primary
        return (
            ScreenGeometry.cgRect(fromAppKit: screen.frame, primaryScreenHeight: primaryHeight),
            ScreenGeometry.cgRect(fromAppKit: screen.visibleFrame, primaryScreenHeight: primaryHeight)
        )
    }
}
