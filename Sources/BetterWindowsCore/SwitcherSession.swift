/// Selection state while the switcher panel is up: which entry is
/// highlighted, moved by Tab / Shift-Tab with wrap-around.
public struct SwitcherSession {
    public let count: Int
    public private(set) var selectedIndex: Int

    /// nil when there is nothing to switch between. With two or more
    /// windows the initial selection is the *second* most recent, so a
    /// quick Option-Tab flips straight back to the previous window.
    public init?(count: Int) {
        guard count > 0 else { return nil }
        self.count = count
        selectedIndex = count > 1 ? 1 : 0
    }

    public mutating func advance() {
        selectedIndex = (selectedIndex + 1) % count
    }

    public mutating func retreat() {
        selectedIndex = (selectedIndex - 1 + count) % count
    }
}
