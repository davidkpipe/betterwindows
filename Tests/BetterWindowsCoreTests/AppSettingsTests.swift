import XCTest
import BetterWindowsCore

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testIsEnabledDefaultsToTrueOnFirstLaunch() {
        XCTAssertTrue(AppSettings(defaults: defaults).isEnabled)
    }

    func testDisablingPersistsToAFreshInstanceOverTheSameStore() {
        AppSettings(defaults: defaults).isEnabled = false

        // A new instance reading the same store simulates an app relaunch.
        XCTAssertFalse(AppSettings(defaults: defaults).isEnabled)
    }

    func testReEnablingPersistsAfterADisable() {
        let settings = AppSettings(defaults: defaults)
        settings.isEnabled = false
        settings.isEnabled = true

        XCTAssertTrue(AppSettings(defaults: defaults).isEnabled)
    }

    func testDragSnappingDefaultsToEnabledAndPersists() {
        XCTAssertTrue(AppSettings(defaults: defaults).isDragSnappingEnabled)

        AppSettings(defaults: defaults).isDragSnappingEnabled = false

        XCTAssertFalse(AppSettings(defaults: defaults).isDragSnappingEnabled)
    }

    func testOnboardingCompletionDefaultsToFalseAndPersists() {
        XCTAssertFalse(AppSettings(defaults: defaults).hasCompletedOnboarding)

        AppSettings(defaults: defaults).hasCompletedOnboarding = true

        XCTAssertTrue(AppSettings(defaults: defaults).hasCompletedOnboarding)
    }

    func testHotkeyBindingsRoundTrip() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertNil(settings.storedHotkeyBindings(), "nothing stored on first launch")

        let bindings: [SnapAction: HotkeyBinding] = [
            .maximize: HotkeyBinding(keyCode: 36, modifiers: 6144),
            .restore: HotkeyBinding(keyCode: 51, modifiers: 6144),
        ]
        settings.storeHotkeyBindings(bindings)

        XCTAssertEqual(AppSettings(defaults: defaults).storedHotkeyBindings(), bindings)
    }
}
