/// MRU (most-recently-used) ordering for the window switcher, generic over
/// the app's window identity so it can be unit tested without the OS.
///
/// The model deliberately holds no window metadata: the app snapshots live
/// windows fresh on every switcher invocation and asks the model to order
/// them, so closed windows vanish structurally and titles are never stale.
public struct WindowListModel<ID: Hashable> {
    /// Focus history, most recent first.
    public private(set) var mruIDs: [ID] = []

    public init() {}

    /// Moves the window to the front (inserting if unknown) — call on every
    /// focus change and after the switcher activates a window.
    public mutating func noteFocused(_ id: ID) {
        if let index = mruIDs.firstIndex(of: id) {
            mruIDs.remove(at: index)
        }
        mruIDs.insert(id, at: 0)
    }

    /// Forgets a window immediately (e.g. on a close notification). Windows
    /// that die without one are dropped by `prune` on the next snapshot.
    public mutating func noteClosed(_ id: ID) {
        mruIDs.removeAll { $0 == id }
    }

    /// Drops history entries whose windows no longer exist.
    public mutating func prune(keeping live: some Sequence<ID>) {
        let live = Set(live)
        mruIDs.removeAll { !live.contains($0) }
    }

    /// Orders a fresh snapshot by focus history: windows with history first,
    /// most recent first, then the rest in snapshot order — new windows the
    /// user never focused sort after the ones they actually use.
    public func ordered<Entry>(_ snapshot: [Entry], id: (Entry) -> ID) -> [Entry] {
        let rank = Dictionary(
            mruIDs.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var known: [(rank: Int, entry: Entry)] = []
        var unknown: [Entry] = []
        for entry in snapshot {
            if let rank = rank[id(entry)] {
                known.append((rank, entry))
            } else {
                unknown.append(entry)
            }
        }
        known.sort { $0.rank < $1.rank }
        return known.map(\.entry) + unknown
    }
}
