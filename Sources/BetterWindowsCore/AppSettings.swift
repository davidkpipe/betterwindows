import Foundation

/// User-facing settings persisted across launches.
///
/// Backed by `UserDefaults`; inject a custom suite for testing.
public final class AppSettings {
    public static let isEnabledKey = "isEnabled"
    public static let isDragSnappingEnabledKey = "isDragSnappingEnabled"
    public static let hotkeyBindingsKey = "hotkeyBindings"
    public static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Master switch for all BetterWindows behavior. Defaults to enabled
    /// so the app works on first launch without configuration.
    public var isEnabled: Bool {
        get { defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.isEnabledKey) }
    }

    /// Whether drag-to-edge snapping is active. Hotkeys are unaffected.
    public var isDragSnappingEnabled: Bool {
        get { defaults.object(forKey: Self.isDragSnappingEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.isDragSnappingEnabledKey) }
    }

    /// Whether the user has closed the onboarding window at least once;
    /// automatic presentation at launch stops after that.
    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Self.hasCompletedOnboardingKey) }
        set { defaults.set(newValue, forKey: Self.hasCompletedOnboardingKey) }
    }

    // MARK: Hotkey bindings

    /// The persisted hotkey map — nil on first launch, when callers fall
    /// back to the built-in defaults.
    public func storedHotkeyBindings() -> [SnapAction: HotkeyBinding]? {
        guard let data = defaults.data(forKey: Self.hotkeyBindingsKey) else { return nil }
        return try? JSONDecoder().decode([SnapAction: HotkeyBinding].self, from: data)
    }

    public func storeHotkeyBindings(_ bindings: [SnapAction: HotkeyBinding]) {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        defaults.set(data, forKey: Self.hotkeyBindingsKey)
    }
}
