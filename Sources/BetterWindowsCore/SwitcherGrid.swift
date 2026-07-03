/// Grid geometry for the switcher panel: indices run in MRU order, left to
/// right, top to bottom, and arrow-key moves wrap.
///
/// The wrap rules: right/left step through the whole list in MRU order —
/// exactly the Tab / Shift-Tab sequence — wrapping at the ends; down/up move
/// within the column, wrapping vertically, with a ragged last row skipped
/// over rather than blocking the move.
public struct SwitcherGrid {
    public let count: Int
    public let columns: Int

    public init?(count: Int, maxColumns: Int) {
        guard count > 0, maxColumns > 0 else { return nil }
        self.count = count
        columns = min(count, maxColumns)
    }

    public var rows: Int {
        (count + columns - 1) / columns
    }

    public func row(of index: Int) -> Int {
        index / columns
    }

    public func column(of index: Int) -> Int {
        index % columns
    }

    public func right(of index: Int) -> Int {
        (index + 1) % count
    }

    public func left(of index: Int) -> Int {
        (index - 1 + count) % count
    }

    public func down(of index: Int) -> Int {
        guard rows > 1 else { return index }
        let next = index + columns
        return next < count ? next : column(of: index)
    }

    public func up(of index: Int) -> Int {
        guard rows > 1 else { return index }
        let previous = index - columns
        if previous >= 0 { return previous }
        let column = column(of: index)
        let bottomRow = (count - 1 - column) / columns
        return bottomRow * columns + column
    }
}
