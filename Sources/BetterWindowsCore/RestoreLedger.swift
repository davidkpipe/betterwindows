import CoreGraphics

/// Remembers each window's pre-snap frame so it can be restored later.
///
/// Semantics per the PRD: the frame is recorded on the FIRST snap only, so
/// chaining snaps (left half → quarter → maximize) keeps the original frame;
/// restore consumes the entry; closing a window drops it. Pure and generic
/// over the window identity — no OS dependencies.
public struct RestoreLedger<WindowID: Hashable> {
    private var preSnapFrames: [WindowID: CGRect] = [:]

    public init() {}

    /// Records `frame` as the window's pre-snap frame unless one is already
    /// recorded. Call with the window's current frame before applying a snap.
    public mutating func recordPreSnapFrame(_ frame: CGRect, for window: WindowID) {
        guard preSnapFrames[window] == nil else { return }
        preSnapFrames[window] = frame
    }

    /// The window's pre-snap frame, removed from the ledger. Nil when the
    /// window was never snapped — restore is then a no-op.
    public mutating func consumeRestoreFrame(for window: WindowID) -> CGRect? {
        preSnapFrames.removeValue(forKey: window)
    }

    /// Whether the window currently has a recorded pre-snap frame.
    public func isSnapped(_ window: WindowID) -> Bool {
        preSnapFrames[window] != nil
    }

    /// Drops the entry for a window that no longer exists.
    public mutating func removeEntry(for window: WindowID) {
        preSnapFrames.removeValue(forKey: window)
    }
}
