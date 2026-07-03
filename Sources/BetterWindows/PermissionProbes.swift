import AppKit
import CoreGraphics

/// Read-only checks for the states the onboarding window reports. All are
/// cheap enough to poll once a second while the window is visible.
enum PermissionProbes {
    static func accessibilityGranted() -> Bool {
        WindowControl.isTrusted()
    }

    static func screenRecordingGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Whether macOS's own drag-to-edge tiling is on — the setting
    /// BetterWindows recommends disabling to avoid double-snapping.
    /// nil on macOS 14, which has no such feature.
    static func nativeTilingEnabled() -> Bool? {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15 else {
            return nil
        }
        let value = CFPreferencesCopyAppValue(
            "EnableTilingByEdgeDrag" as CFString,
            "com.apple.WindowManager" as CFString
        )
        // Unset means the user never touched it: the macOS 15+ default is on.
        return (value as? Bool) ?? true
    }
}
