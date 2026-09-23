import Collaboration
import CoreGraphics
import Foundation

/// The login session the app runs in: whether its screen is locked, and whether its user may read the log.
public enum LoginSession {
    /// Whether the screen is locked now, as the window server says (`CGSSessionScreenIsLocked`); false when
    /// the session cannot be read.
    public static var screenIsLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    /// Whether this session is the one at the keyboard (`kCGSessionOnConsoleKey`). With another user's
    /// session in front, the key is theirs, whatever the log shows this one; false when the session cannot
    /// be read, which leaves the key to macOS.
    public static var isOnConsole: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session[kCGSessionOnConsoleKey as String] as? Bool) ?? false
    }

    /// Whether the user is an administrator, a member of the `admin` group (80): the one kind of account
    /// that reads the unified log without sudo. Asked of the directory service, so a membership through a
    /// nested group counts; false when it cannot answer.
    public static var userIsAdministrator: Bool {
        let authority = CBIdentityAuthority.default()
        guard let user = CBUserIdentity(posixUID: getuid(), authority: authority),
              let admin = CBGroupIdentity(posixGID: 80, authority: authority) else { return false }
        return user.isMember(ofGroup: admin)
    }
}
