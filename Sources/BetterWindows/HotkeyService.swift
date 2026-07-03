import Carbon.HIToolbox

/// Global hotkeys via the Carbon hotkey API: no extra permissions required,
/// and registered combos are consumed before reaching other apps.
final class HotkeyService {
    private static let signature: OSType = "BWIN".utf8.reduce(0) { ($0 << 8) + OSType($1) }

    private var handlerRef: EventHandlerRef?
    private var registrations: [UInt32: (ref: EventHotKeyRef, handler: () -> Void)] = [:]
    private var nextID: UInt32 = 1

    init() {
        var pressed = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                    .fire(id: hotKeyID.id)
                return noErr
            },
            1,
            &pressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    deinit {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    /// Registers a system-wide hotkey. `modifiers` takes Carbon flags
    /// (`controlKey`, `optionKey`, ...). Returns false when registration
    /// fails, e.g. the combo is reserved by another app.
    @discardableResult
    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) -> Bool {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: nextID)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        registrations[nextID] = (ref, handler)
        nextID += 1
        return true
    }

    /// Removes every registered hotkey (used before re-applying an edited
    /// binding set).
    func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
    }

    private func fire(id: UInt32) {
        registrations[id]?.handler()
    }
}
