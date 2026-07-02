import CoreGraphics

/// Maps a cursor position on a display to the drag-snap zone it activates.
///
/// Coordinates are Accessibility/CG space (top-left origin). Only the zones
/// the PRD assigns to drag targets participate: left/right edges → halves,
/// top edge → maximize, corners → quarters. The bottom edge and the interior
/// are never drag zones; top/bottom halves and center stay hotkey-only.
///
/// The active zone is "sticky": its regions grow by `hysteresis` while it is
/// current, so cursor jitter at a boundary cannot flicker the preview. A
/// corner can still take over an active edge zone immediately, because it is
/// the more specific target.
public struct SnapHitTester {
    /// How close (points) to an edge the cursor must be to activate it.
    public var edgeThickness: CGFloat
    /// How far (points) along an edge from a corner still counts as the corner.
    public var cornerSize: CGFloat
    /// Extra slack applied to the active zone's regions before it is dropped.
    public var hysteresis: CGFloat

    public init(edgeThickness: CGFloat = 8, cornerSize: CGFloat = 128, hysteresis: CGFloat = 16) {
        self.edgeThickness = edgeThickness
        self.cornerSize = cornerSize
        self.hysteresis = hysteresis
    }

    /// The zone for `point` on the display occupying `displayFrame` (the
    /// full frame, not the visible frame — zones hug the physical edges).
    /// Pass the previously returned zone as `current` to get hysteresis.
    public func zone(
        at point: CGPoint,
        in displayFrame: CGRect,
        current: SnapZone? = nil
    ) -> SnapZone? {
        if let current, contains(current, point: point, in: displayFrame, slack: hysteresis) {
            if let fresh = classify(point, in: displayFrame),
               specificity(of: fresh) > specificity(of: current) {
                return fresh
            }
            return current
        }
        return classify(point, in: displayFrame)
    }

    /// Ordered most-specific first so corners win over the edges they touch.
    private static let dragZones: [SnapZone] = [
        .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter,
        .leftHalf, .rightHalf, .maximize,
    ]

    private func classify(_ point: CGPoint, in frame: CGRect) -> SnapZone? {
        Self.dragZones.first { contains($0, point: point, in: frame, slack: 0) }
    }

    private func specificity(of zone: SnapZone) -> Int {
        switch zone {
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            return 2
        default:
            return 1
        }
    }

    private func contains(_ zone: SnapZone, point p: CGPoint, in f: CGRect, slack: CGFloat) -> Bool {
        let edge = edgeThickness + slack
        let corner = cornerSize + slack
        let left = p.x - f.minX
        let right = f.maxX - p.x
        let top = p.y - f.minY
        let bottom = f.maxY - p.y

        switch zone {
        case .leftHalf:
            return left <= edge
        case .rightHalf:
            return right <= edge
        case .maximize:
            return top <= edge
        case .topLeftQuarter:
            return (left <= edge && top <= corner) || (top <= edge && left <= corner)
        case .topRightQuarter:
            return (right <= edge && top <= corner) || (top <= edge && right <= corner)
        case .bottomLeftQuarter:
            return (left <= edge && bottom <= corner) || (bottom <= edge && left <= corner)
        case .bottomRightQuarter:
            return (right <= edge && bottom <= corner) || (bottom <= edge && right <= corner)
        case .topHalf, .bottomHalf, .center:
            return false
        }
    }
}
