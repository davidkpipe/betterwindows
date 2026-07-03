import BetterWindowsCore
import Foundation

/// App-side owner of the hotkey map: persistence and change notification on
/// top of the pure HotkeyPreferences.
final class HotkeyStore {
    private(set) var preferences: HotkeyPreferences
    private let settings: AppSettings

    /// Fired after a successful assignment so registrations refresh
    /// immediately.
    var onChange: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        preferences = HotkeyPreferences(
            bindings: settings.storedHotkeyBindings() ?? SnapAction.defaultBindings
        )
    }

    func binding(for action: SnapAction) -> HotkeyBinding? {
        preferences.binding(for: action)
    }

    func assign(_ binding: HotkeyBinding, to action: SnapAction) -> HotkeyPreferences.AssignmentResult {
        let result = preferences.assign(binding, to: action)
        if result == .assigned {
            settings.storeHotkeyBindings(preferences.bindings)
            onChange?()
        }
        return result
    }
}
