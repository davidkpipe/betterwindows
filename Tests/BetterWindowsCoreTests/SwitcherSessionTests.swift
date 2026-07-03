import XCTest
import BetterWindowsCore

final class SwitcherSessionTests: XCTestCase {
    func testNoSessionWhenThereAreNoWindows() {
        XCTAssertNil(SwitcherSession(count: 0))
    }

    func testSingleWindowStartsSelected() {
        XCTAssertEqual(SwitcherSession(count: 1)?.selectedIndex, 0)
    }

    func testInitialSelectionIsThePreviousWindow() {
        XCTAssertEqual(
            SwitcherSession(count: 5)?.selectedIndex, 1,
            "quick Option-Tab must flip to the second most recent window"
        )
    }

    func testAdvanceWrapsPastTheEnd() {
        var session = SwitcherSession(count: 3)!

        session.advance() // 1 -> 2
        session.advance() // 2 -> wraps to 0

        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testRetreatWrapsBackward() {
        var session = SwitcherSession(count: 3)!

        session.retreat() // 1 -> 0
        session.retreat() // 0 -> wraps to 2

        XCTAssertEqual(session.selectedIndex, 2)
    }

    func testSingleWindowCyclingStaysPut() {
        var session = SwitcherSession(count: 1)!

        session.advance()
        session.retreat()

        XCTAssertEqual(session.selectedIndex, 0)
    }
}
