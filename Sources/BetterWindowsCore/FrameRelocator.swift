import Foundation

/// Keeps restored frames on attached displays: a window whose pre-snap
/// display has been disconnected must land fully visible somewhere real,
/// not off the edge of the world.
public enum FrameRelocator {
    /// The fraction of a frame's area that must be visible for it to count
    /// as on-screen and stay untouched.
    public static let minimumVisibleFraction: CGFloat = 0.5

    /// Returns `frame` unchanged when at least half of it is visible across
    /// the given displays — a window deliberately straddling two monitors
    /// stays put. Otherwise repositions it into the nearest display's
    /// visible frame, preserving its size (shrinking only when the frame is
    /// bigger than that display) and its center where possible, so it lands
    /// fully visible.
    public static func ensureVisible(_ frame: CGRect, in visibleFrames: [CGRect]) -> CGRect {
        guard !visibleFrames.isEmpty else { return frame }

        let frameArea = frame.width * frame.height
        guard frameArea > 0 else { return frame }

        // Displays never overlap, so per-display intersections sum cleanly.
        let visibleArea = visibleFrames.reduce(CGFloat(0)) { total, visible in
            let clip = frame.intersection(visible)
            return total + (clip.isNull ? 0 : clip.width * clip.height)
        }
        if visibleArea / frameArea >= minimumVisibleFraction {
            return frame
        }

        let home = nearestDisplay(to: frame, among: visibleFrames)
        let size = CGSize(
            width: min(frame.width, home.width),
            height: min(frame.height, home.height)
        )
        let x = clamp(frame.midX - size.width / 2, min: home.minX, max: home.maxX - size.width)
        let y = clamp(frame.midY - size.height / 2, min: home.minY, max: home.maxY - size.height)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func nearestDisplay(to frame: CGRect, among visibleFrames: [CGRect]) -> CGRect {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return visibleFrames.min { lhs, rhs in
            distanceSquared(from: center, to: lhs) < distanceSquared(from: center, to: rhs)
        } ?? visibleFrames[0]
    }

    /// Squared distance from a point to a rect; zero inside it.
    private static func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), Swift.max(lower, upper))
    }
}
