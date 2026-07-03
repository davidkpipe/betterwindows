/// Every user-invokable snap action: the ten zones plus restore.
public enum SnapAction: String, CaseIterable, Codable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case maximize
    case center
    case restore

    /// The zone this action snaps to; nil for restore, which consults the
    /// restore ledger instead of the zone geometry.
    public var zone: SnapZone? {
        switch self {
        case .leftHalf: return .leftHalf
        case .rightHalf: return .rightHalf
        case .topHalf: return .topHalf
        case .bottomHalf: return .bottomHalf
        case .topLeftQuarter: return .topLeftQuarter
        case .topRightQuarter: return .topRightQuarter
        case .bottomLeftQuarter: return .bottomLeftQuarter
        case .bottomRightQuarter: return .bottomRightQuarter
        case .maximize: return .maximize
        case .center: return .center
        case .restore: return nil
        }
    }

    /// Name shown in the settings window and in conflict messages.
    public var displayName: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeftQuarter: return "Top-Left Quarter"
        case .topRightQuarter: return "Top-Right Quarter"
        case .bottomLeftQuarter: return "Bottom-Left Quarter"
        case .bottomRightQuarter: return "Bottom-Right Quarter"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .restore: return "Restore"
        }
    }
}
