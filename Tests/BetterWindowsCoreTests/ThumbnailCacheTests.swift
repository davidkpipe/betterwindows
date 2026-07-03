import XCTest
import BetterWindowsCore

final class ThumbnailCacheTests: XCTestCase {
    private var cache = ThumbnailCache<String, String>()

    func testStoredImageIsRetrievableAndFresh() {
        cache.beginInvocation()

        cache.store("capture-1", for: "w")

        XCTAssertEqual(cache.image(for: "w"), "capture-1")
        XCTAssertTrue(cache.isFresh("w"))
    }

    func testNewInvocationKeepsOldImageAsPlaceholderButMarksItStale() {
        cache.beginInvocation()
        cache.store("old", for: "w")

        cache.beginInvocation()

        XCTAssertEqual(cache.image(for: "w"), "old", "stale beats blank as a placeholder")
        XCTAssertFalse(cache.isFresh("w"), "a prior invocation's capture must not count as current")
    }

    func testRecaptureRefreshesStaleEntry() {
        cache.beginInvocation()
        cache.store("old", for: "w")
        cache.beginInvocation()

        cache.store("new", for: "w")

        XCTAssertEqual(cache.image(for: "w"), "new")
        XCTAssertTrue(cache.isFresh("w"))
    }

    func testPruneDropsEntriesForClosedWindows() {
        cache.store("a", for: "alive")
        cache.store("b", for: "closed")

        cache.prune(keeping: ["alive"])

        XCTAssertEqual(cache.image(for: "alive"), "a")
        XCTAssertNil(cache.image(for: "closed"))
    }

    func testUnknownWindowHasNoImageAndIsNotFresh() {
        cache.beginInvocation()

        XCTAssertNil(cache.image(for: "unknown"))
        XCTAssertFalse(cache.isFresh("unknown"))
    }
}
