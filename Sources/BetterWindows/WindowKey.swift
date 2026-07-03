import ApplicationServices

/// Hashable wrapper — AXUIElements obtained separately for the same window
/// compare CFEqual, so they can key ledgers and the switcher's MRU history.
struct WindowKey: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}
