import XCTest
import BetterWindowsCore

final class WindowListModelTests: XCTestCase {
    /// Stand-in for the app's window snapshot entries: an identity plus the
    /// metadata the model must carry through untouched.
    private struct Window: Equatable {
        let id: String
        var isMinimized = false
    }

    private var model = WindowListModel<String>()

    private func ordered(_ snapshot: [Window]) -> [String] {
        model.ordered(snapshot, id: \.id).map(\.id)
    }

    func testFocusChangeMovesWindowToTheFront() {
        model.noteFocused("a")
        model.noteFocused("b")
        model.noteFocused("c")

        model.noteFocused("a")

        let snapshot = [Window(id: "a"), Window(id: "b"), Window(id: "c")]
        XCTAssertEqual(ordered(snapshot), ["a", "c", "b"])
    }

    func testQuickFlipTargetIsTheSecondMostRecent() {
        model.noteFocused("older")
        model.noteFocused("current")

        let snapshot = [Window(id: "older"), Window(id: "current"), Window(id: "new")]
        let ids = ordered(snapshot)

        XCTAssertEqual(ids.first, "current")
        XCTAssertEqual(ids[1], "older", "index 1 is the initial selection — the flip target")
    }

    func testWindowsWithoutHistoryFollowInSnapshotOrder() {
        model.noteFocused("known")

        let snapshot = [Window(id: "x"), Window(id: "known"), Window(id: "y")]
        XCTAssertEqual(ordered(snapshot), ["known", "x", "y"])
    }

    func testMinimizedWindowsAreIncludedAndKeepTheirMRUPosition() {
        model.noteFocused("visible")
        model.noteFocused("minimized")
        model.noteFocused("front")

        let snapshot = [
            Window(id: "visible"),
            Window(id: "minimized", isMinimized: true),
            Window(id: "front"),
        ]
        let result = model.ordered(snapshot, id: \.id)

        XCTAssertEqual(result.map(\.id), ["front", "minimized", "visible"])
        XCTAssertTrue(result[1].isMinimized, "metadata must survive ordering")
    }

    func testNoteClosedRemovesTheWindowFromHistory() {
        model.noteFocused("a")
        model.noteFocused("b")

        model.noteClosed("b")

        XCTAssertEqual(model.mruIDs, ["a"])
        let snapshot = [Window(id: "a"), Window(id: "b")]
        XCTAssertEqual(ordered(snapshot), ["a", "b"], "b is now unknown and sorts by snapshot order")
    }

    func testPruneDropsWindowsMissingFromTheLiveSnapshot() {
        model.noteFocused("dead")
        model.noteFocused("alive")

        model.prune(keeping: ["alive"])

        XCTAssertEqual(model.mruIDs, ["alive"])
    }

    func testOrderedReturnsEveryLiveWindowExactlyOnce() {
        model.noteFocused("b")
        model.noteFocused("d")

        let snapshot = ["a", "b", "c", "d", "e"].map { Window(id: $0) }
        let ids = ordered(snapshot)

        XCTAssertEqual(ids.count, snapshot.count)
        XCTAssertEqual(Set(ids), Set(snapshot.map(\.id)))
        XCTAssertEqual(ids, ["d", "b", "a", "c", "e"])
    }
}
