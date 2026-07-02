import Foundation

/// User-facing settings persisted across launches.
///
/// Backed by `UserDefaults`; inject a custom suite for testing.
public final class AppSettings {
    public static let isEnabledKey = "isEnabled"

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
}
