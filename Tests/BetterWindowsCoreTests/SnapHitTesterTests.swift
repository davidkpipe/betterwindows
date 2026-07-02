import XCTest
import BetterWindowsCore

final class SnapHitTesterTests: XCTestCase {
    // 1600x1000 display whose top-left corner is the global origin.
    // Defaults: edgeThickness 8, cornerSize 128, hysteresis 16.
    private let display = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let tester = SnapHitTester()

    func testEdgesMapToTheirZones() {
        XCTAssertEqual(tester.zone(at: CGPoint(x: 2, y: 500), in: display), .leftHalf)
        XCTAssertEqual(tester.zone(at: CGPoint(x: 1598, y: 500), in: display), .rightHalf)
        XCTAssertEqual(tester.zone(at: CGPoint(x: 800, y: 2), in: display), .maximize)
    }

    func testBottomEdgeIsNotAZone() {
        XCTAssertNil(tester.zone(at: CGPoint(x: 800, y: 998), in: display))
    }

    func testInteriorIsNotAZone() {
        XCTAssertNil(tester.zone(at: CGPoint(x: 800, y: 500), in: display))
        // Diagonally near a corner but away from both edges.
        XCTAssertNil(tester.zone(at: CGPoint(x: 100, y: 100), in: display))
    }

    func testCornersHitFromEitherEdgeApproach() {
        XCTAssertEqual(tester.zone(at: CGPoint(x: 2, y: 100), in: display), .topLeftQuarter)
        XCTAssertEqual(tester.zone(at: CGPoint(x: 100, y: 2), in: display), .topLeftQuarter)
        XCTAssertEqual(tester.zone(at: CGPoint(x: 1598, y: 100), in: display), .topRightQuarter)
        XCTAssertEqual(tester.zone(at: CGPoint(x: 100, y: 998), in: display), .bottomLeftQuarter)
        XCTAssertEqual(tester.zone(at: CGPoint(x: 1598, y: 900), in: display), .bottomRightQuarter)
    }

    func testHysteresisKeepsTheActiveZoneNearItsBoundary() {
        // 20pt from the edge: beyond the 8pt entry band, inside the 24pt sticky band.
        let drifted = CGPoint(x: 20, y: 500)

        XCTAssertNil(tester.zone(at: drifted, in: display, current: nil))
        XCTAssertEqual(tester.zone(at: drifted, in: display, current: .leftHalf), .leftHalf)
        // Beyond the sticky band the zone is dropped.
        XCTAssertNil(tester.zone(at: CGPoint(x: 30, y: 500), in: display, current: .leftHalf))
    }

    func testCornerTakesOverAnActiveEdgeZone() {
        XCTAssertEqual(
            tester.zone(at: CGPoint(x: 2, y: 100), in: display, current: .leftHalf),
            .topLeftQuarter
        )
    }

    func testActiveCornerIsStickyAlongTheEdge() {
        // 132pt is past the 128pt corner extent but inside its sticky band.
        XCTAssertEqual(
            tester.zone(at: CGPoint(x: 2, y: 132), in: display, current: .topLeftQuarter),
            .topLeftQuarter
        )
        // Well past the sticky band the corner yields to the edge zone.
        XCTAssertEqual(
            tester.zone(at: CGPoint(x: 2, y: 200), in: display, current: .topLeftQuarter),
            .leftHalf
        )
    }

    func testOffsetDisplayUsesItsOwnEdges() {
        let secondary = CGRect(x: -1440, y: 300, width: 1440, height: 900)

        XCTAssertEqual(tester.zone(at: CGPoint(x: -1438, y: 700), in: secondary), .leftHalf)
        XCTAssertEqual(tester.zone(at: CGPoint(x: -2, y: 700), in: secondary), .rightHalf)
    }
}
