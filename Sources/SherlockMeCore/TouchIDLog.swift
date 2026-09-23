import Foundation

/// What the unified log says about the Touch ID key, the sensor and the screen: the only lines SherlockMe
/// reads. Measured on macOS 27.0 (26A428) with a Magic Keyboard with Touch ID (`docs/macOS.md`, *What a
/// Touch ID key press does*). Every one is logged at the default level, which an administrator account
/// reads without sudo.
public enum TouchIDEvent: Equatable, Sendable {
    /// biometrickitd `touchIDButtonPressed: 1`: the key went down, 0.31 s before loginwindow hears of it.
    case keyDown
    /// loginwindow `handleSystemEvent:` locking the screen on the key itself, 0.31 s after it went down.
    case macOSLocksForKey
    /// biometrickitd `match:withOptions:`: something started reading the sensor. After a lock, it is the
    /// lock screen, 0.03 to 0.15 s after the screen locked.
    case readStart
    /// biometrickitd status 63: a finger is on the sensor. Reported only while something reads it.
    case fingerOn
    /// biometrickitd status 64: the finger left the sensor.
    case fingerOff
    /// loginwindow sent `com.apple.screenIsLocked`.
    case screenLocked
    /// loginwindow sent `com.apple.screenIsUnlocked`.
    case screenUnlocked
}

/// Reading those lines: the predicate `log stream` is given, and what one line of its output means.
public enum TouchIDLog {
    /// The lines SherlockMe reads and nothing else, so the stream prints nothing between presses. What keeping
    /// it open costs the system's log daemons is not measured (`docs/manual-test-checklist.md` §1).
    public static let predicate = """
        (process == "biometrickitd" AND (eventMessage BEGINSWITH "touchIDButtonPressed: 1" \
        OR eventMessage BEGINSWITH "match:withOptions" \
        OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 63," \
        OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 64,")) \
        OR (process == "loginwindow" AND (eventMessage CONTAINS "sendDistributedNotification: com.apple.screenIs" \
        OR eventMessage CONTAINS "calling to lock screen immediate"))
        """

    /// What a line means, from the name of the process that wrote it and its message; nil for any other line.
    public static func event(process: String, message: String) -> TouchIDEvent? {
        switch process {
        case "biometrickitd":
            if message.hasPrefix("touchIDButtonPressed: 1") { return .keyDown }
            if message.hasPrefix("match:withOptions") { return .readStart }
            if message.hasPrefix("statusMessage:withData:timestamp: 63,") { return .fingerOn }
            if message.hasPrefix("statusMessage:withData:timestamp: 64,") { return .fingerOff }
        case "loginwindow":
            if message.contains("sendDistributedNotification: com.apple.screenIsLocked") { return .screenLocked }
            if message.contains("sendDistributedNotification: com.apple.screenIsUnlocked") { return .screenUnlocked }
            if message.contains("handleSystemEvent:"), message.contains("calling to lock screen immediate") {
                return .macOSLocksForKey
            }
        default:
            break
        }
        return nil
    }

    /// The log's own time stamp, `2026-09-23 11:48:21.425235+0200`; nil when it does not parse.
    public static func time(_ stamp: String) -> Date? { stampFormat.date(from: stamp) }

    /// One line of `log stream --style ndjson`: when it was written and what it means. nil for a line that
    /// is not one of these, or not a log entry at all (the stream opens with a line saying what it filters).
    public static func parse(_ line: Data) -> (time: Date, event: TouchIDEvent)? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let stamp = object["timestamp"] as? String, let time = time(stamp),
              let path = object["processImagePath"] as? String,
              let message = object["eventMessage"] as? String,
              let event = event(process: (path as NSString).lastPathComponent, message: message)
        else { return nil }
        return (time, event)
    }

    private static let stampFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        return formatter
    }()
}
