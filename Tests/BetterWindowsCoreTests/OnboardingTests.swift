import XCTest
import BetterWindowsCore

final class OnboardingTests: XCTestCase {
    // MARK: Auto-present gate

    func testAutoPresentsOnFirstLaunchWithMissingPermissions() {
        XCTAssertTrue(
            OnboardingGate.shouldAutoPresent(
                hasCompletedOnboarding: false,
                allPermissionsGranted: false
            )
        )
    }

    func testDoesNotAutoPresentOnceCompleted() {
        XCTAssertFalse(
            OnboardingGate.shouldAutoPresent(
                hasCompletedOnboarding: true,
                allPermissionsGranted: false
            )
        )
        XCTAssertFalse(
            OnboardingGate.shouldAutoPresent(
                hasCompletedOnboarding: true,
                allPermissionsGranted: true
            )
        )
    }

    func testDoesNotAutoPresentWhenEverythingIsAlreadyGranted() {
        XCTAssertFalse(
            OnboardingGate.shouldAutoPresent(
                hasCompletedOnboarding: false,
                allPermissionsGranted: true
            )
        )
    }

    // MARK: Catalog

    func testCatalogListsAccessibilityScreenRecordingAndTilingInOrder() {
        XCTAssertEqual(
            OnboardingCatalog.items.map(\.id),
            ["accessibility", "screenRecording", "nativeTiling"]
        )
    }

    func testEveryItemHasAValidDistinctSystemSettingsDeepLink() {
        for item in OnboardingCatalog.items {
            let url = URL(string: item.settingsURLString)
            XCTAssertEqual(
                url?.scheme, "x-apple.systempreferences",
                "bad deep link for \(item.id)"
            )
        }
        XCTAssertEqual(
            Set(OnboardingCatalog.items.map(\.settingsURLString)).count,
            OnboardingCatalog.items.count,
            "each item must link to its own pane"
        )
    }

    func testCopyExplainsPerItemDegradationRatherThanGrantEverything() {
        XCTAssertEqual(OnboardingCatalog.accessibility.kind, .requiredPermission)
        XCTAssertTrue(
            OnboardingCatalog.accessibility.detail.localizedCaseInsensitiveContains("snap"),
            "accessibility copy must name the feature that needs it"
        )

        XCTAssertEqual(OnboardingCatalog.screenRecording.kind, .optionalPermission)
        XCTAssertTrue(
            OnboardingCatalog.screenRecording.detail.localizedCaseInsensitiveContains("thumbnail")
        )
        XCTAssertTrue(
            OnboardingCatalog.screenRecording.detail.localizedCaseInsensitiveContains("switcher")
        )

        XCTAssertEqual(OnboardingCatalog.nativeTiling.kind, .recommendation)
        XCTAssertTrue(
            OnboardingCatalog.nativeTiling.detail.localizedCaseInsensitiveContains("tiling")
        )

        for item in OnboardingCatalog.items {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.detail.isEmpty)
        }
    }
}
