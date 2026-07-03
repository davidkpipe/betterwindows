import XCTest
import BetterWindowsCore

final class DragSessionTests: XCTestCase {
    private var session = DragSession() // 4pt movement threshold

    func testBeginFromIdleRecordsStartAndGoesPressed() {
        session.begin(at: CGPoint(x: 10, y: 20))

        XCTAssertEqual(session.phase, .pressed)
        XCTAssertEqual(session.startPoint, CGPoint(x: 10, y: 20))
    }

    func testBeginWhileActiveIsIgnored() {
        session.begin(at: CGPoint(x: 10, y: 20))
        session.begin(at: CGPoint(x: 500, y: 500))

        XCTAssertEqual(session.startPoint, CGPoint(x: 10, y: 20))
    }

    func testMovementBelowThresholdStaysPressed() {
        session.begin(at: CGPoint(x: 100, y: 100))

        XCTAssertEqual(session.move(to: CGPoint(x: 102, y: 102)), .pressed)
    }

    func testCrossingThresholdStartsDragging() {
        session.begin(at: CGPoint(x: 100, y: 100))

        // hypot(3, 3) ≈ 4.24 ≥ 4pt threshold.
        XCTAssertEqual(session.move(to: CGPoint(x: 103, y: 103)), .dragging)
        // And it stays dragging on further movement.
        XCTAssertEqual(session.move(to: CGPoint(x: 100, y: 100)), .dragging)
    }

    func testMoveWhileIdleStaysIdle() {
        XCTAssertEqual(session.move(to: CGPoint(x: 500, y: 500)), .idle)
    }

    func testEndFromDraggingReturnsTrueAndResets() {
        session.begin(at: CGPoint(x: 0, y: 0))
        session.move(to: CGPoint(x: 50, y: 0))

        XCTAssertTrue(session.end())
        XCTAssertEqual(session.phase, .idle)
        XCTAssertNil(session.startPoint)
    }

    func testEndFromPressedIsAPlainClick() {
        session.begin(at: CGPoint(x: 0, y: 0))

        XCTAssertFalse(session.end())
        XCTAssertEqual(session.phase, .idle)
    }

    func testCancelSuppressesTheRestOfTheSession() {
        session.begin(at: CGPoint(x: 0, y: 0))
        session.move(to: CGPoint(x: 50, y: 0))

        session.cancel()

        XCTAssertEqual(session.phase, .cancelled)
        XCTAssertEqual(session.move(to: CGPoint(x: 200, y: 200)), .cancelled)
        XCTAssertFalse(session.end(), "a cancelled session must not report a drag on release")

        // After release the machine is reusable.
        session.begin(at: CGPoint(x: 1, y: 1))
        XCTAssertEqual(session.phase, .pressed)
    }

    func testCancelWhileIdleIsIgnored() {
        session.cancel()

        XCTAssertEqual(session.phase, .idle)
    }

    func testCustomThresholdIsRespected() {
        var wide = DragSession(movementThreshold: 100)
        wide.begin(at: CGPoint(x: 0, y: 0))

        XCTAssertEqual(wide.move(to: CGPoint(x: 99, y: 0)), .pressed)
        XCTAssertEqual(wide.move(to: CGPoint(x: 100, y: 0)), .dragging)
    }
}
