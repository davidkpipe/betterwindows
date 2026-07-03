import Foundation

/// A snap action's key combo: Carbon virtual key code plus Carbon modifier
/// flags.
public struct HotkeyBinding: Equatable, Hashable, Codable, Sendable {
    public var keyCode: Int
    public var modifiers: Int

    public init(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// The hotkey map with duplicate rejection. Pure — persistence lives with
/// the caller.
public struct HotkeyPreferences {
    public enum AssignmentResult: Equatable {
        case assigned
        case conflict(with: SnapAction)
    }

    public private(set) var bindings: [SnapAction: HotkeyBinding]

    public init(bindings: [SnapAction: HotkeyBinding]) {
        self.bindings = bindings
    }

    public func binding(for action: SnapAction) -> HotkeyBinding? {
        bindings[action]
    }

    /// The action currently holding `binding`, if any.
    public func owner(of binding: HotkeyBinding) -> SnapAction? {
        bindings.first(where: { $0.value == binding })?.key
    }

    /// Assigns `binding` to `action`. A combo held by another action is
    /// rejected; re-recording an action's own combo succeeds unchanged.
    public mutating func assign(_ binding: HotkeyBinding, to action: SnapAction) -> AssignmentResult {
        if let owner = owner(of: binding), owner != action {
            return .conflict(with: owner)
        }
        bindings[action] = binding
        return .assigned
    }
}
