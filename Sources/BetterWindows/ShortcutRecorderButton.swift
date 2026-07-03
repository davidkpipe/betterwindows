import AppKit
import BetterWindowsCore
import Carbon.HIToolbox

/// A button that records a key combo: click it, then press the new shortcut.
/// Esc (or losing focus) cancels. The owner validates the combo — e.g.
/// duplicate rejection — via `onRecord`, and the button reflects the result.
final class ShortcutRecorderButton: NSButton {
    var onRecord: ((HotkeyBinding) -> HotkeyPreferences.AssignmentResult)?

    private var isRecording = false
    private var assignedTitle = "Record Shortcut"

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        title = assignedTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    func display(binding: HotkeyBinding?) {
        assignedTitle = binding.map(Self.symbolString(for:)) ?? "Record Shortcut"
        if !isRecording {
            title = assignedTitle
        }
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Type shortcut…"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if Int(event.keyCode) == kVK_Escape {
            endRecording()
            return
        }
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        // Require a real chord — at least one of ⌃, ⌥, ⌘ — so plain typing
        // cannot become a global hotkey.
        guard modifiers & (controlKey | optionKey | cmdKey) != 0 else {
            NSSound.beep()
            return
        }
        let binding = HotkeyBinding(keyCode: Int(event.keyCode), modifiers: modifiers)
        switch onRecord?(binding) {
        case .conflict(let owner):
            NSSound.beep()
            title = "Used by \(owner.displayName)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self, self.isRecording else { return }
                self.title = "Type shortcut…"
            }
        case .assigned, nil:
            assignedTitle = Self.symbolString(for: binding)
            endRecording()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // ⌘-combos arrive here instead of keyDown; capture them while
        // recording.
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            endRecording()
        }
        return super.resignFirstResponder()
    }

    private func endRecording() {
        isRecording = false
        title = assignedTitle
    }

    // MARK: Formatting

    static func symbolString(for binding: HotkeyBinding) -> String {
        var parts = ""
        if binding.modifiers & controlKey != 0 { parts += "⌃" }
        if binding.modifiers & optionKey != 0 { parts += "⌥" }
        if binding.modifiers & shiftKey != 0 { parts += "⇧" }
        if binding.modifiers & cmdKey != 0 { parts += "⌘" }
        return parts + KeyCodeNames.name(for: binding.keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        if flags.contains(.command) { carbon |= cmdKey }
        return carbon
    }
}
