import CoreGraphics

/// The snap targets BetterWindows understands. Left/right halves, maximize,
/// and quarters can be reached by dragging to screen edges; top/bottom halves
/// and center are hotkey-only.
public enum SnapZone: CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case maximize
    case center
}

/// Pure zone→frame geometry. No OS dependencies — tests run headless.
public enum SnapEngine {
    /// The frame a window should get for `zone`, in Accessibility/CG
    /// coordinates (top-left origin, y grows down). `visibleFrame` is the
    /// destination display's visible frame (menu bar and Dock already
    /// excluded) in the same space. `windowFrame` is the window's current
    /// frame; only `.center` reads it — centering keeps the window's size,
    /// clamped to the visible frame.
    public static func targetFrame(
        for zone: SnapZone,
        visibleFrame v: CGRect,
        windowFrame: CGRect
    ) -> CGRect {
        // Split points are rounded to whole points so complementary zones
        // tile exactly even on odd-sized frames.
        let midX = (v.minX + v.width / 2).rounded()
        let midY = (v.minY + v.height / 2).rounded()

        switch zone {
        case .maximize:
            return v
        case .leftHalf:
            return CGRect(x: v.minX, y: v.minY, width: midX - v.minX, height: v.height)
        case .rightHalf:
            return CGRect(x: midX, y: v.minY, width: v.maxX - midX, height: v.height)
        case .topHalf:
            return CGRect(x: v.minX, y: v.minY, width: v.width, height: midY - v.minY)
        case .bottomHalf:
            return CGRect(x: v.minX, y: midY, width: v.width, height: v.maxY - midY)
        case .topLeftQuarter:
            return CGRect(x: v.minX, y: v.minY, width: midX - v.minX, height: midY - v.minY)
        case .topRightQuarter:
            return CGRect(x: midX, y: v.minY, width: v.maxX - midX, height: midY - v.minY)
        case .bottomLeftQuarter:
            return CGRect(x: v.minX, y: midY, width: midX - v.minX, height: v.maxY - midY)
        case .bottomRightQuarter:
            return CGRect(x: midX, y: midY, width: v.maxX - midX, height: v.maxY - midY)
        case .center:
            let size = CGSize(
                width: min(windowFrame.width, v.width),
                height: min(windowFrame.height, v.height)
            )
            return CGRect(
                x: (v.minX + (v.width - size.width) / 2).rounded(),
                y: (v.minY + (v.height - size.height) / 2).rounded(),
                width: size.width,
                height: size.height
            )
        }
    }

    /// Where a torn-off (un-snapped) window sits while its drag continues:
    /// the original size, positioned so the cursor keeps the same relative
    /// horizontal grip it had on the snapped frame and its vertical offset
    /// from the top edge (clamped into the restored height).
    public static func tearOffFrame(
        originalSize: CGSize,
        cursor: CGPoint,
        grabPoint: CGPoint,
        snappedFrame: CGRect
    ) -> CGRect {
        let relativeX = snappedFrame.width > 0
            ? min(max((grabPoint.x - snappedFrame.minX) / snappedFrame.width, 0), 1)
            : 0.5
        let grabOffsetY = min(
            max(grabPoint.y - snappedFrame.minY, 0),
            max(originalSize.height - 1, 0)
        )
        return CGRect(
            x: cursor.x - originalSize.width * relativeX,
            y: cursor.y - grabOffsetY,
            width: originalSize.width,
            height: originalSize.height
        )
    }
}
