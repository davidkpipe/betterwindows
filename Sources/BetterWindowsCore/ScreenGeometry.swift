import CoreGraphics

/// Conversions between AppKit screen coordinates (origin at the bottom-left
/// corner of the primary display, y grows upward) and the space used by the
/// Accessibility and CoreGraphics window APIs (origin at the top-left corner
/// of the primary display, y grows downward).
public enum ScreenGeometry {
    /// Converts a rect from AppKit space to Accessibility/CG space.
    /// `primaryScreenHeight` is the full frame height of the primary display.
    public static func cgRect(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Converts a rect from Accessibility/CG space to AppKit space.
    public static func appKitRect(fromCG rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        // The flip is its own inverse.
        cgRect(fromAppKit: rect, primaryScreenHeight: primaryScreenHeight)
    }
}
