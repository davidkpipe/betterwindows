import XCTest
import BetterWindowsCore

final class SwitcherGridTests: XCTestCase {
    // A ragged 4-column grid of 10:
    //   0 1 2 3
    //   4 5 6 7
    //   8 9
    private let ragged = SwitcherGrid(count: 10, maxColumns: 4)!

    func testNoGridForZeroWindowsOrZeroColumns() {
        XCTAssertNil(SwitcherGrid(count: 0, maxColumns: 4))
        XCTAssertNil(SwitcherGrid(count: 4, maxColumns: 0))
    }

    func testColumnsClampToCountAndRowsRoundUp() {
        XCTAssertEqual(SwitcherGrid(count: 3, maxColumns: 8)?.columns, 3)
        XCTAssertEqual(SwitcherGrid(count: 3, maxColumns: 8)?.rows, 1)
        XCTAssertEqual(ragged.columns, 4)
        XCTAssertEqual(ragged.rows, 3)
    }

    func testRightStepsInMRUOrderLikeTabAndWraps() {
        XCTAssertEqual(ragged.right(of: 0), 1)
        XCTAssertEqual(ragged.right(of: 3), 4, "row end continues to the next row")
        XCTAssertEqual(ragged.right(of: 9), 0, "list end wraps to the start")
    }

    func testLeftStepsBackwardLikeShiftTabAndWraps() {
        XCTAssertEqual(ragged.left(of: 1), 0)
        XCTAssertEqual(ragged.left(of: 4), 3, "row start continues to the previous row")
        XCTAssertEqual(ragged.left(of: 0), 9, "list start wraps to the end")
    }

    func testDownMovesWithinTheColumnAndWrapsToTheTop() {
        XCTAssertEqual(ragged.down(of: 0), 4)
        XCTAssertEqual(ragged.down(of: 4), 8)
        XCTAssertEqual(ragged.down(of: 8), 0, "bottom of a full column wraps to the top")
        XCTAssertEqual(ragged.down(of: 6), 2, "a column the ragged row lacks wraps past it")
        XCTAssertEqual(ragged.down(of: 7), 3)
    }

    func testUpMovesWithinTheColumnAndWrapsToTheBottomMostCell() {
        XCTAssertEqual(ragged.up(of: 8), 4)
        XCTAssertEqual(ragged.up(of: 0), 8, "wraps to the bottom of a full column")
        XCTAssertEqual(ragged.up(of: 2), 6, "wraps to the last existing cell of a ragged column")
        XCTAssertEqual(ragged.up(of: 1), 9)
    }

    func testSingleRowVerticalMovesAreNoOps() {
        let row = SwitcherGrid(count: 3, maxColumns: 8)!

        XCTAssertEqual(row.down(of: 1), 1)
        XCTAssertEqual(row.up(of: 1), 1)
        XCTAssertEqual(row.right(of: 2), 0, "horizontal cycling still works")
    }

    func testRowAndColumnLookups() {
        XCTAssertEqual(ragged.row(of: 6), 1)
        XCTAssertEqual(ragged.column(of: 6), 2)
        XCTAssertEqual(ragged.row(of: 9), 2)
        XCTAssertEqual(ragged.column(of: 9), 1)
    }
}
