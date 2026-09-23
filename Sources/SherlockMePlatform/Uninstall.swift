import AppKit
import Foundation
import SherlockMeCore

/// Which part of taking the app off a Mac did not work. The words a user reads are the app target's:
/// this one only says which step, and what the system said about it.
public enum UninstallStep: Sendable, Hashable {
    case loginItem
    case bundleToTrash
    case storedState
    // TEMPLATE: one case per system registration the app makes and must give back, for instance a
    // `permissionGrant` reset with `tccutil`, or a launch agent booted out.
}

public struct UninstallFailure: Sendable, Hashable {
    public let step: UninstallStep
    public let reason: String
    public init(step: UninstallStep, reason: String) {
        self.step = step
        self.reason = reason
    }
}

/// Everything the app put on a Mac outside its own bundle, taken off.
///
/// **Dragging the bundle to the Trash is not an uninstall.** It removes the app and nothing else: the login
/// item registered with `SMAppService` stays, so System Settings › General › Login Items goes on listing an
/// app that is not there and offering to start it, and any permission the app was granted stays in the
/// privacy list, where a later build signed by the same team inherits a decision nobody remembers making.
public enum Uninstall {
    /// The system registrations, **while the bundle they name is still where they name it**: a `tccutil
    /// reset` against a bundle identifier with no bundle behind it fails, and nothing puts that right
    /// afterwards, so this runs before the app goes anywhere.
    ///
    /// TEMPLATE: a permission the app was granted is given back here first, with
    /// `run("/usr/bin/tccutil", ["reset", "<Service>", bundleIdentifier])`; it exits non-zero when it had
    /// nothing to reset as well as when it failed, so the sentence the user reads names where to look
    /// either way.
    @MainActor
    public static func removeSystemRegistrations() -> [UninstallFailure] {
        var failed: [UninstallFailure] = []
        let bundleIdentifier = AppIdentity.bundleIdentifier
        if LoginItem.isEnabled {
            do { try LoginItem.setEnabled(false) }
            catch { failed.append(.init(step: .loginItem, reason: error.localizedDescription)) }
        }
        _ = resetNotificationGrant(bundleIdentifier)
        return failed
    }

    /// Notification authorization lives in usernoted's group preferences, and no public API puts it back to
    /// "not asked yet". Left behind, a reinstall inherits a decision the user made once about an app they
    /// have since removed, and can never be asked again. Its failure is not worth a sentence: an update
    /// this app cannot announce is the whole of the cost.
    private static func resetNotificationGrant(_ bundleIdentifier: String) -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/Library/Preferences/group.com.apple.usernoted.plist")
        guard let data = try? Data(contentsOf: url),
              var plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let apps = plist["apps"] as? [[String: Any]] else { return false }
        let kept = apps.filter { ($0["bundle-id"] as? String) != bundleIdentifier }
        guard kept.count != apps.count else { return true }
        plist["apps"] = kept
        guard let out = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0),
              (try? out.write(to: url)) != nil else { return false }
        for daemon in ["usernoted", "NotificationCenter"] { run("/usr/bin/killall", [daemon]) }
        return true
    }

    /// The Trash, not a delete: the app the user has just removed is still there to put back.
    @MainActor
    public static func moveBundleToTrash(_ completion: @escaping @MainActor (UninstallFailure?) -> Void) {
        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            let failure = error.map { UninstallFailure(step: .bundleToTrash, reason: $0.localizedDescription) }
            DispatchQueue.main.async { completion(failure) }
        }
    }

    /// The preferences and the support folder, handed to a process that outlives this one, and started just
    /// before the quit. `UninstallPlan` says why they cannot be removed here.
    @MainActor
    public static func startHelper() -> UninstallFailure? {
        let script = UninstallPlan.helperScript(pid: getpid(),
                                                supportDirectory: Paths.appSupport.path,
                                                bundleIdentifier: AppIdentity.bundleIdentifier,
                                                home: FileManager.default.homeDirectoryForCurrentUser.path)
        do {
            try DetachedProcess.spawn(executable: "/bin/sh", arguments: ["-c", script], environment: [:])
            return nil
        } catch {
            return .init(step: .storedState, reason: "\(error)")
        }
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
