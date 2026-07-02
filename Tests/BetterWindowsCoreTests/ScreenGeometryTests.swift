import XCTest
import BetterWindowsCore

final class ScreenGeometryTests: XCTestCase {
    func testPrimaryScreenVisibleFrameConvertsToTopLeftOrigin() {
        // 1600x1000 primary display with a 25pt menu bar and a 75pt Dock:
        // AppKit's visibleFrame starts 75pt up and is 900pt tall.
        let visible = CGRect(x: 0, y: 75, width: 1600, height: 900)

        let cg = ScreenGeometry.cgRect(fromAppKit: visible, primaryScreenHeight: 1000)

        // In CG space the same area starts just below the 25pt menu bar.
        XCTAssertEqual(cg, CGRect(x: 0, y: 25, width: 1600, height: 900))
    }

    func testScreenAbovePrimaryGetsNegativeY() {
        // A display stacked directly above the primary occupies AppKit
        // y = 1000...2000, which is CG y = -1000...0.
        let frame = CGRect(x: 0, y: 1000, width: 1600, height: 1000)

        let cg = ScreenGeometry.cgRect(fromAppKit: frame, primaryScreenHeight: 1000)

        XCTAssertEqual(cg, CGRect(x: 0, y: -1000, width: 1600, height: 1000))
    }

    func testConversionIsItsOwnInverse() {
        let rect = CGRect(x: -800, y: 120, width: 1440, height: 877)

        let roundTripped = ScreenGeometry.appKitRect(
            fromCG: ScreenGeometry.cgRect(fromAppKit: rect, primaryScreenHeight: 1169),
            primaryScreenHeight: 1169
        )

        XCTAssertEqual(roundTripped, rect)
    }
}
