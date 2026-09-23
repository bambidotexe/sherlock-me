import Foundation

/// The rules that turn what was found into a level. Every page that reports one of these states reads it
/// from here, so the System page's permission row and the Health page's agree.
public enum HealthRules {
    /// A macOS permission, or a setup the app asks for in its onboarding wizard: green while it is in
    /// place; missing, **red when the wizard marks it required** (the app cannot work without it) and orange
    /// otherwise (a feature that needs it cannot work, and the rest can).
    public static func grant(held: Bool, required: Bool) -> HealthLevel {
        if held { return .good }
        return required ? .failure : .warning
    }
}

extension HealthRules {
    /// Whether a file in `~/Library/Logs/DiagnosticReports` is a crash report of the process named
    /// `process`: the name, a dash, the date the system stamps (`SherlockMe-2026-09-21-101010.ips`), and the
    /// extension of a crash report old or new. A user fault of the same process (`ExcUserFault_…`), or
    /// another process whose name merely starts the same way, is not.
    public static func isCrashReport(fileName: String, process: String) -> Bool {
        guard fileName.hasPrefix(process + "-"), fileName.hasSuffix(".ips") || fileName.hasSuffix(".crash")
        else { return false }
        let stamp = fileName.dropFirst(process.count + 1)
        // yyyy-MM-dd-HHmmss, digits where the date's digits go.
        let pattern = Array("0000-00-00-000000")
        guard stamp.count > pattern.count else { return false }
        return zip(stamp, pattern).allSatisfy { char, slot in slot == "-" ? char == "-" : char.isASCII && char.isNumber }
    }
}

/// What `SMAppService` says about the app as a login item, in the app's own words.
public enum LoginItemState: Equatable, Sendable {
    case enabled
    /// Not registered: the switch is off, which is the user's to decide.
    case disabled
    /// Registered, then switched off in System Settings › General › Login Items & Extensions.
    case needsApproval
}
