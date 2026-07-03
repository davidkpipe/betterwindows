import XCTest
import BetterWindowsCore

final class FrameRelocatorTests: XCTestCase {
    // CG-space visible frames: a menu-barred main display and one to its right.
    private let main = CGRect(x: 0, y: 25, width: 1600, height: 875)
    private let side = CGRect(x: 1600, y: 0, width: 1200, height: 800)
    private var displays: [CGRect] { [main, side] }

    func testFullyVisibleFrameIsUntouched() {
        let frame = CGRect(x: 200, y: 100, width: 800, height: 600)

        XCTAssertEqual(FrameRelocator.ensureVisible(frame, in: displays), frame)
    }

    func testFrameStraddlingTwoDisplaysStaysPut() {
        // Half on each display — fully visible in total, a deliberate layout.
        let frame = CGRect(x: 1200, y: 200, width: 800, height: 400)

        XCTAssertEqual(FrameRelocator.ensureVisible(frame, in: displays), frame)
    }

    func testFrameOnADisconnectedDisplayLandsFullyVisibleOnTheNearest() {
        // Entirely beyond the right display — where a third monitor used to be.
        let frame = CGRect(x: 3400, y: 100, width: 600, height: 400)

        let relocated = FrameRelocator.ensureVisible(frame, in: displays)

        XCTAssertEqual(relocated, CGRect(x: 2200, y: 100, width: 600, height: 400))
        XCTAssertTrue(side.contains(relocated), "must land fully inside the nearest display")
        XCTAssertEqual(relocated.size, frame.size, "size is preserved when it fits")
    }

    func testMostlyOffscreenFrameIsPulledFullyOnScreen() {
        // Only ~17% visible at the left edge of the main display.
        let frame = CGRect(x: -500, y: 100, width: 600, height: 300)

        let relocated = FrameRelocator.ensureVisible(frame, in: displays)

        XCTAssertEqual(relocated, CGRect(x: 0, y: 100, width: 600, height: 300))
        XCTAssertTrue(main.contains(relocated))
    }

    func testOversizedFrameShrinksToTheNearestDisplay() {
        let frame = CGRect(x: 5000, y: 2000, width: 2000, height: 1000)

        let relocated = FrameRelocator.ensureVisible(frame, in: displays)

        XCTAssertEqual(relocated, side, "bigger than the display in both axes fills it exactly")
    }

    func testMajorityVisibleOversizedFrameIsLeftAlone() {
        // Hangs off the main display but well over half of it is visible.
        let frame = CGRect(x: 100, y: 50, width: 2000, height: 1000)

        XCTAssertEqual(FrameRelocator.ensureVisible(frame, in: displays), frame)
    }

    func testNoDisplaysLeaveTheFrameAlone() {
        let frame = CGRect(x: 3400, y: 100, width: 600, height: 400)

        XCTAssertEqual(FrameRelocator.ensureVisible(frame, in: []), frame)
    }
}
