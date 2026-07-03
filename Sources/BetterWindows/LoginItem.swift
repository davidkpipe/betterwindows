import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService. Registration only works from a real
/// .app bundle; unbundled `swift run` builds report `unavailable`.
enum LoginItem {
    enum State {
        case enabled
        case disabled
        case unavailable(reason: String)
    }

    static var state: State {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return .unavailable(
                reason: "Launch at login needs an app bundle — build one with Scripts/make-app-bundle.sh."
            )
        }
        return SMAppService.mainApp.status == .enabled ? .enabled : .disabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
