import Foundation

/// loginwindow's session agent, reached through the private login.framework, loaded once and looked up with
/// `dlsym`. On macOS 27 `SACLockScreenImmediate` is in the session agent's public interface
/// (`LFSessionAgentListenerPublicInterface`), which needs no entitlement (`docs/macOS.md`).
public enum SessionAgent {
    private typealias Call = @convention(c) () -> Int32

    private static let lockCall: Call? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_NOW),
              let address = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(address, to: Call.self)
    }()

    /// Whether this macOS has the call. Looked up, never made.
    public static var canLock: Bool { lockCall != nil }

    /// Locks the screen now: loginwindow's own immediate lock, the one the Touch ID key runs. Measured: the
    /// Mac locked 0.09 to 0.14 s after the key went down when this was called on the key's log line (runs 7
    /// to 9). A synchronous round trip to loginwindow; 0 on success, -1 when the call is missing.
    @discardableResult
    public static func lockScreen() -> Int32 { lockCall?() ?? -1 }
}
