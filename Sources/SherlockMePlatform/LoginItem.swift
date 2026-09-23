import SherlockMeCore
import ServiceManagement

/// Launch at login. The state lives in `SMAppService` and nowhere else: the user can remove SherlockMe in
/// System Settings › General › Login Items without ever opening this app, so a copy of the answer kept in
/// the settings file could only ever disagree with the one that decides.
public enum LoginItem {
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// The same answer with one more distinction: registered, then switched off in System Settings, which is
    /// a login that will not happen although the app asked for it.
    public static var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        default: .disabled
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
