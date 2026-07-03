import XCTest
import BetterWindowsCore

final class SnapEngineTests: XCTestCase {
    /// Visible frames (CG coordinates) for a variety of display layouts:
    /// menu bar with Dock at the bottom, Dock on the left, Dock on the right,
    /// a display left of the primary, a large display up-right of it, and an
    /// odd width that does not halve evenly.
    private let layouts: [CGRect] = [
        CGRect(x: 0, y: 25, width: 1600, height: 900),
        CGRect(x: 70, y: 25, width: 1530, height: 975),
        CGRect(x: 0, y: 25, width: 1530, height: 975),
        CGRect(x: -1440, y: 33, width: 1440, height: 867),
        CGRect(x: 1600, y: -200, width: 2560, height: 1415),
        CGRect(x: 0, y: 25, width: 1601, height: 975),
    ]

    private let window = CGRect(x: 200, y: 200, width: 800, height: 600)

    private func frame(_ zone: SnapZone, _ v: CGRect) -> CGRect {
        SnapEngine.targetFrame(for: zone, visibleFrame: v, windowFrame: window)
    }

    func testLeftAndRightHalvesTileEveryLayoutExactly() {
        for v in layouts {
            let left = frame(.leftHalf, v)
            let right = frame(.rightHalf, v)
            XCTAssertEqual(left.minX, v.minX)
            XCTAssertEqual(left.minY, v.minY)
            XCTAssertEqual(left.height, v.height)
            XCTAssertEqual(right.maxX, v.maxX)
            XCTAssertEqual(right.height, v.height)
            XCTAssertEqual(left.maxX, right.minX, "halves must meet with no gap or overlap in \(v)")
            XCTAssertEqual(left.width + right.width, v.width)
        }
    }

    func testTopAndBottomHalvesTileEveryLayoutExactly() {
        for v in layouts {
            let top = frame(.topHalf, v)
            let bottom = frame(.bottomHalf, v)
            XCTAssertEqual(top.minY, v.minY)
            XCTAssertEqual(top.width, v.width)
            XCTAssertEqual(bottom.maxY, v.maxY)
            XCTAssertEqual(bottom.width, v.width)
            XCTAssertEqual(top.maxY, bottom.minY, "halves must meet with no gap or overlap in \(v)")
            XCTAssertEqual(top.height + bottom.height, v.height)
        }
    }

    func testQuartersTileEveryLayoutExactly() {
        for v in layouts {
            let tl = frame(.topLeftQuarter, v)
            let tr = frame(.topRightQuarter, v)
            let bl = frame(.bottomLeftQuarter, v)
            let br = frame(.bottomRightQuarter, v)
            XCTAssertEqual(tl.origin, v.origin)
            XCTAssertEqual(tr.maxX, v.maxX)
            XCTAssertEqual(tr.minY, v.minY)
            XCTAssertEqual(bl.minX, v.minX)
            XCTAssertEqual(bl.maxY, v.maxY)
            XCTAssertEqual(br.maxX, v.maxX)
            XCTAssertEqual(br.maxY, v.maxY)
            XCTAssertEqual(tl.maxX, tr.minX)
            XCTAssertEqual(tl.maxY, bl.minY)
            XCTAssertEqual(tl.width + tr.width, v.width)
            XCTAssertEqual(tl.height + bl.height, v.height)
        }
    }

    func testMaximizeReturnsTheVisibleFrame() {
        for v in layouts {
            XCTAssertEqual(frame(.maximize, v), v)
        }
    }

    func testCenterKeepsWindowSizeAndCenters() {
        let v = CGRect(x: 0, y: 25, width: 1600, height: 900)

        let centered = frame(.center, v)

        XCTAssertEqual(centered.size, window.size)
        XCTAssertEqual(centered.midX, v.midX, accuracy: 0.5)
        XCTAssertEqual(centered.midY, v.midY, accuracy: 0.5)
    }

    func testCenterClampsAWindowLargerThanTheVisibleFrame() {
        let v = CGRect(x: 70, y: 25, width: 1530, height: 975)
        let huge = CGRect(x: 0, y: 0, width: 5000, height: 4000)

        let centered = SnapEngine.targetFrame(for: .center, visibleFrame: v, windowFrame: huge)

        XCTAssertEqual(centered, v)
    }

    func testTearOffKeepsRelativeHorizontalGripAndTopOffset() {
        // Snapped 800pt-wide half, grabbed at 25% of its width, 12pt below
        // the top edge; the cursor is now mid-screen.
        let snapped = CGRect(x: 0, y: 25, width: 800, height: 975)
        let grab = CGPoint(x: 200, y: 37)
        let cursor = CGPoint(x: 900, y: 400)

        let torn = SnapEngine.tearOffFrame(
            originalSize: CGSize(width: 400, height: 300),
            cursor: cursor,
            grabPoint: grab,
            snappedFrame: snapped
        )

        XCTAssertEqual(torn.size, CGSize(width: 400, height: 300))
        XCTAssertEqual(torn.minX, 800, "cursor keeps its 25% grip: 900 - 400 x 0.25")
        XCTAssertEqual(torn.minY, 388, "top edge stays 12pt above the cursor")
    }

    func testTearOffClampsAGrabDeeperThanTheOriginalHeight() {
        // Grabbed far below where the restored window's bottom edge will be:
        // the torn frame must still contain the cursor vertically.
        let snapped = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let grabAndCursor = CGPoint(x: 500, y: 600)

        let torn = SnapEngine.tearOffFrame(
            originalSize: CGSize(width: 300, height: 200),
            cursor: grabAndCursor,
            grabPoint: grabAndCursor,
            snappedFrame: snapped
        )

        XCTAssertTrue(torn.minY <= grabAndCursor.y && grabAndCursor.y <= torn.maxY)
    }

    func testTearOffWithADegenerateSnappedFrameCentersHorizontally() {
        let torn = SnapEngine.tearOffFrame(
            originalSize: CGSize(width: 400, height: 300),
            cursor: CGPoint(x: 500, y: 100),
            grabPoint: CGPoint(x: 500, y: 100),
            snappedFrame: CGRect(x: 500, y: 100, width: 0, height: 0)
        )

        XCTAssertEqual(torn.midX, 500)
    }

    func testEveryZoneStaysWithinTheVisibleFrame() {
        for v in layouts {
            for zone in SnapZone.allCases {
                let f = frame(zone, v)
                XCTAssertTrue(
                    v.insetBy(dx: -0.01, dy: -0.01).contains(f),
                    "\(zone) escapes \(v): \(f)"
                )
            }
        }
    }
}
