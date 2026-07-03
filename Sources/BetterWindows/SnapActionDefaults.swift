import BetterWindowsCore
import Carbon.HIToolbox

extension SnapAction {
    /// The built-in ⌃⌥ layout, used until the user records their own.
    static let defaultBindings: [SnapAction: HotkeyBinding] = {
        let combo = controlKey | optionKey
        return [
            .leftHalf: HotkeyBinding(keyCode: kVK_LeftArrow, modifiers: combo),
            .rightHalf: HotkeyBinding(keyCode: kVK_RightArrow, modifiers: combo),
            .topHalf: HotkeyBinding(keyCode: kVK_UpArrow, modifiers: combo),
            .bottomHalf: HotkeyBinding(keyCode: kVK_DownArrow, modifiers: combo),
            .topLeftQuarter: HotkeyBinding(keyCode: kVK_ANSI_U, modifiers: combo),
            .topRightQuarter: HotkeyBinding(keyCode: kVK_ANSI_I, modifiers: combo),
            .bottomLeftQuarter: HotkeyBinding(keyCode: kVK_ANSI_J, modifiers: combo),
            .bottomRightQuarter: HotkeyBinding(keyCode: kVK_ANSI_K, modifiers: combo),
            .maximize: HotkeyBinding(keyCode: kVK_Return, modifiers: combo),
            .center: HotkeyBinding(keyCode: kVK_ANSI_C, modifiers: combo),
            .restore: HotkeyBinding(keyCode: kVK_Delete, modifiers: combo),
        ]
    }()
}
