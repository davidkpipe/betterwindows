import Foundation

/// One onboarding checklist entry: a permission BetterWindows needs (or a
/// system setting it recommends changing), the copy explaining what degrades
/// without it, and the System Settings deep link that fixes it.
public struct OnboardingItem: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Snapping cannot work at all without this.
        case requiredPermission
        /// A feature degrades without this but the app still works.
        case optionalPermission
        /// Not a permission — a system setting worth changing.
        case recommendation
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let detail: String
    public let settingsURLString: String

    public init(id: String, kind: Kind, title: String, detail: String, settingsURLString: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.settingsURLString = settingsURLString
    }
}

/// The fixed set of items the onboarding window walks through, with
/// per-item degradation copy rather than a generic "grant everything".
public enum OnboardingCatalog {
    public static let accessibility = OnboardingItem(
        id: "accessibility",
        kind: .requiredPermission,
        title: "Accessibility",
        detail: "Moving and resizing windows uses the macOS Accessibility API. "
            + "Without this permission, drag snapping and every snap hotkey stay off.",
        settingsURLString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    public static let screenRecording = OnboardingItem(
        id: "screenRecording",
        kind: .optionalPermission,
        title: "Screen Recording",
        detail: "Only used to show window thumbnails in the Option-Tab switcher. "
            + "Without it, the switcher still works but lists windows by icon and title only.",
        settingsURLString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )

    public static let nativeTiling = OnboardingItem(
        id: "nativeTiling",
        kind: .recommendation,
        title: "macOS Window Tiling",
        detail: "macOS's built-in drag-to-edge tiling competes with BetterWindows "
            + "and can snap the same drag twice. Recommended: turn off "
            + "\u{201C}Drag windows to screen edges to tile\u{201D} in Desktop & Dock.",
        settingsURLString: "x-apple.systempreferences:com.apple.Desktop-Settings.extension"
    )

    /// Display order in the onboarding window.
    public static let items = [accessibility, screenRecording, nativeTiling]
}

/// Decides when onboarding presents itself at launch (it is always
/// reachable manually from the status-item menu).
public enum OnboardingGate {
    /// Auto-present until the user has closed onboarding once, and only
    /// while a permission is actually missing — an install where everything
    /// is already granted has nothing to onboard.
    public static func shouldAutoPresent(
        hasCompletedOnboarding: Bool,
        allPermissionsGranted: Bool
    ) -> Bool {
        !hasCompletedOnboarding && !allPermissionsGranted
    }
}
