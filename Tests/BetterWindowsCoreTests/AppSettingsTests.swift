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
}
