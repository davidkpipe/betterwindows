import CoreGraphics

/// Pure state machine for one mouse-drag lifecycle. Knows nothing about
/// windows or zones — it tracks phases and the movement threshold that
/// separates a click from a drag. Cancellation (Esc or disqualification)
/// suppresses the rest of the session until the button is released.
public struct DragSession {
    public enum Phase: Equatable {
        case idle
        case pressed
        case dragging
        case cancelled
    }

    public private(set) var phase: Phase = .idle
    public private(set) var startPoint: CGPoint?

    private let movementThreshold: CGFloat

    public init(movementThreshold: CGFloat = 4) {
        self.movementThreshold = movementThreshold
    }

    /// Mouse down. Starts a session only from idle.
    public mutating func begin(at point: CGPoint) {
        guard phase == .idle else { return }
        phase = .pressed
        startPoint = point
    }

    /// Mouse moved with the button down. Crossing the movement threshold
    /// turns the press into a drag. Returns the phase after the move.
    @discardableResult
    public mutating func move(to point: CGPoint) -> Phase {
        if phase == .pressed,
           let start = startPoint,
           hypot(point.x - start.x, point.y - start.y) >= movementThreshold {
            phase = .dragging
        }
        return phase
    }

    /// Mouse up. Resets to idle; returns true when a qualifying drag was in
    /// progress — the release a snap commit may act on.
    @discardableResult
    public mutating func end() -> Bool {
        let wasDragging = phase == .dragging
        phase = .idle
        startPoint = nil
        return wasDragging
    }

    /// Cancels the session (e.g. Esc); further movement is ignored until the
    /// button is released.
    public mutating func cancel() {
        guard phase == .pressed || phase == .dragging else { return }
        phase = .cancelled
        startPoint = nil
    }
}
