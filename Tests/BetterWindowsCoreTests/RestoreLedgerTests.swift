import XCTest
import BetterWindowsCore

final class RestoreLedgerTests: XCTestCase {
    private var ledger = RestoreLedger<String>()
    private let original = CGRect(x: 120, y: 80, width: 900, height: 700)

    func testFirstSnapRecordsThePreSnapFrame() {
        ledger.recordPreSnapFrame(original, for: "w")

        XCTAssertTrue(ledger.isSnapped("w"))
        XCTAssertEqual(ledger.consumeRestoreFrame(for: "w"), original)
    }

    func testChainedSnapsKeepTheOriginalFrame() {
        ledger.recordPreSnapFrame(original, for: "w")
        // The window now sits in a zone; further snaps must not overwrite.
        ledger.recordPreSnapFrame(CGRect(x: 0, y: 25, width: 800, height: 975), for: "w")
        ledger.recordPreSnapFrame(CGRect(x: 0, y: 25, width: 800, height: 487), for: "w")

        XCTAssertEqual(ledger.consumeRestoreFrame(for: "w"), original)
    }

    func testConsumeClearsTheEntry() {
        ledger.recordPreSnapFrame(original, for: "w")

        XCTAssertEqual(ledger.consumeRestoreFrame(for: "w"), original)
        XCTAssertFalse(ledger.isSnapped("w"))
        XCTAssertNil(ledger.consumeRestoreFrame(for: "w"))
    }

    func testConsumeOnANeverSnappedWindowIsANoOp() {
        XCTAssertNil(ledger.consumeRestoreFrame(for: "never-snapped"))
        XCTAssertFalse(ledger.isSnapped("never-snapped"))
    }

    func testSnapAfterRestoreRecordsTheNewFrame() {
        ledger.recordPreSnapFrame(original, for: "w")
        _ = ledger.consumeRestoreFrame(for: "w")

        let newHome = CGRect(x: 300, y: 300, width: 500, height: 400)
        ledger.recordPreSnapFrame(newHome, for: "w")

        XCTAssertEqual(ledger.consumeRestoreFrame(for: "w"), newHome)
    }

    func testCloseDropsTheEntry() {
        ledger.recordPreSnapFrame(original, for: "w")

        ledger.removeEntry(for: "w")

        XCTAssertFalse(ledger.isSnapped("w"))
        XCTAssertNil(ledger.consumeRestoreFrame(for: "w"))
    }

    func testEntriesAreIndependentPerWindow() {
        let other = CGRect(x: 1, y: 2, width: 300, height: 200)
        ledger.recordPreSnapFrame(original, for: "a")
        ledger.recordPreSnapFrame(other, for: "b")

        ledger.removeEntry(for: "a")

        XCTAssertFalse(ledger.isSnapped("a"))
        XCTAssertEqual(ledger.consumeRestoreFrame(for: "b"), other)
    }
}
