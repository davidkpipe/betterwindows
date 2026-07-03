/// Freshness policy for switcher thumbnails, generic over window identity
/// and image type so it can be unit tested without the OS.
///
/// Each switcher invocation starts a new generation: images captured in an
/// earlier generation stay available as placeholders (better than a blank
/// tile) but read as stale, so the app knows to replace them with a capture
/// taken as of this invocation. Entries for closed windows are dropped by
/// pruning against each fresh window snapshot.
public struct ThumbnailCache<ID: Hashable, Image> {
    private struct Entry {
        var image: Image
        var generation: Int
    }

    private var entries: [ID: Entry] = [:]
    public private(set) var generation = 0

    public init() {}

    /// Starts a new generation; every existing entry becomes stale.
    public mutating func beginInvocation() {
        generation += 1
    }

    /// Stores a capture taken during the current generation.
    public mutating func store(_ image: Image, for id: ID) {
        entries[id] = Entry(image: image, generation: generation)
    }

    /// The latest capture regardless of age — placeholder use.
    public func image(for id: ID) -> Image? {
        entries[id]?.image
    }

    /// Whether the cached capture was taken during the current generation.
    public func isFresh(_ id: ID) -> Bool {
        entries[id]?.generation == generation
    }

    /// Drops entries whose windows no longer exist.
    public mutating func prune(keeping live: some Sequence<ID>) {
        let live = Set(live)
        entries = entries.filter { live.contains($0.key) }
    }
}
