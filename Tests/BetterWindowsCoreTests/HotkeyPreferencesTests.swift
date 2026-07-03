import XCTest
import BetterWindowsCore

final class HotkeyPreferencesTests: XCTestCase {
    private let left = HotkeyBinding(keyCode: 123, modifiers: 6144)
    private let right = HotkeyBinding(keyCode: 124, modifiers: 6144)
    private var prefs = HotkeyPreferences(bindings: [:])

    func testAssignToAnEmptyMapSucceeds() {
        XCTAssertEqual(prefs.assign(left, to: .leftHalf), .assigned)
        XCTAssertEqual(prefs.binding(for: .leftHalf), left)
    }

    func testComboHeldByAnotherActionIsRejectedUnchanged() {
        _ = prefs.assign(left, to: .leftHalf)

        XCTAssertEqual(prefs.assign(left, to: .rightHalf), .conflict(with: .leftHalf))
        XCTAssertNil(prefs.binding(for: .rightHalf))
        XCTAssertEqual(prefs.binding(for: .leftHalf), left)
    }

    func testReRecordingAnActionsOwnComboSucceeds() {
        _ = prefs.assign(left, to: .leftHalf)

        XCTAssertEqual(prefs.assign(left, to: .leftHalf), .assigned)
        XCTAssertEqual(prefs.binding(for: .leftHalf), left)
    }

    func testChangingAComboFreesTheOldOne() {
        _ = prefs.assign(left, to: .leftHalf)
        _ = prefs.assign(right, to: .leftHalf)

        XCTAssertNil(prefs.owner(of: left))
        XCTAssertEqual(prefs.assign(left, to: .rightHalf), .assigned)
    }

    func testOwnerLookup() {
        _ = prefs.assign(left, to: .leftHalf)

        XCTAssertEqual(prefs.owner(of: left), .leftHalf)
        XCTAssertNil(prefs.owner(of: right))
    }

    func testEveryActionExceptRestoreMapsToADistinctZone() {
        let zones = SnapAction.allCases.compactMap(\.zone)

        XCTAssertEqual(zones.count, SnapAction.allCases.count - 1)
        XCTAssertEqual(Set(zones).count, zones.count, "no two actions may share a zone")
        XCTAssertNil(SnapAction.restore.zone)
    }
}
