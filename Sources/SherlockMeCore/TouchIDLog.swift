import Foundation

/// What the unified log says about the Touch ID key, the sensor, the screen and loginwindow's Touch ID hold:
/// the only lines SherlockMe reads. Measured on macOS 27.0 (26A428) with a Magic Keyboard with Touch ID
/// (`docs/macOS.md`, *What a Touch ID key press does*). Every one is logged at the default level, which an
/// administrator account reads without sudo.
public enum TouchIDEvent: Hashable, Sendable {
    /// biometrickitd `touchIDButtonPressed: 1`: the key went down, 0.31 s before loginwindow hears of it.
    case keyDown
    /// loginwindow `handleSystemEvent:` locking the screen on the key itself, 0.31 s after it went down.
    case macOSLocksForKey
    /// biometrickitd `match:withOptions:`: something started reading the sensor. After a lock, it is the
    /// lock screen, 0.03 to 0.15 s after the screen locked; with the screen unlocked, an app whose Touch ID
    /// prompt has just come up.
    case readStart
    /// biometrickitd status 63: a finger is on the sensor. Reported only while something reads it.
    case fingerOn
    /// biometrickitd status 64: the finger left the sensor.
    case fingerOff
    /// loginwindow sent `com.apple.screenIsLocked`.
    case screenLocked
    /// loginwindow sent `com.apple.screenIsUnlocked`.
    case screenUnlocked
    /// loginwindow `addNewTouchIDBlockScreenLockAssertionForClient:`: `client` took loginwindow's Touch ID
    /// hold, under which loginwindow refuses to lock on the key. coreautha takes it the moment any read of
    /// the sensor begins, an app's or the lock screen's, and gives it back when the read ends.
    case holdTaken(client: String, pid: Int32)
    /// loginwindow `clearTouchIDBlockScreenLockAssertionForClient:`: `client` gave the hold back, which
    /// loginwindow keeps `K.holdDebounce` more.
    case holdCleared(client: String, pid: Int32)
}

/// Reading those lines: the predicate `log stream` is given, and what one line of its output means.
public enum TouchIDLog {
    /// The lines SherlockMe reads and nothing else, so the stream prints nothing between presses. Measured:
    /// the `log` child spent 0.7 s of CPU in half an hour of watching (`docs/macOS.md`).
    public static let predicate = """
        (process == "biometrickitd" AND (eventMessage BEGINSWITH "touchIDButtonPressed: 1" \
        OR eventMessage BEGINSWITH "match:withOptions" \
        OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 63," \
        OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 64,")) \
        OR (process == "loginwindow" AND (eventMessage CONTAINS "sendDistributedNotification: com.apple.screenIs" \
        OR eventMessage CONTAINS "calling to lock screen immediate" \
        OR eventMessage CONTAINS "\(holdTakenMarker)" \
        OR eventMessage CONTAINS "\(holdClearedMarker)"))
        """

    /// The payload of loginwindow's two hold lines begins after the method's name and a pipe. The lines that
    /// list the holders, say "already has an assertion" or return a code carry the method's name too, and
    /// none of these markers.
    private static let holdTakenMarker = "| addNewTouchIDBlockScreenLockAssertionForClient: "
    private static let holdClearedMarker = "| clearTouchIDBlockScreenLockAssertionForClient: "

    /// What a line means, from the name of the process that wrote it and its message; nil for any other line.
    /// `uid` is the user whose session this is: the screen's lock and unlock are posted per session, and
    /// another session's are not events of this one.
    public static func event(process: String, message: String, uid: UInt32? = nil) -> TouchIDEvent? {
        switch process {
        case "biometrickitd":
            if message.hasPrefix("touchIDButtonPressed: 1") { return .keyDown }
            if message.hasPrefix("match:withOptions") { return .readStart }
            if message.hasPrefix("statusMessage:withData:timestamp: 63,") { return .fingerOn }
            if message.hasPrefix("statusMessage:withData:timestamp: 64,") { return .fingerOff }
        case "loginwindow":
            if message.contains("sendDistributedNotification: com.apple.screenIsLocked") {
                return isThisSession(message, uid) ? .screenLocked : nil
            }
            if message.contains("sendDistributedNotification: com.apple.screenIsUnlocked") {
                return isThisSession(message, uid) ? .screenUnlocked : nil
            }
            if message.contains("handleSystemEvent:"), message.contains("calling to lock screen immediate") {
                return .macOSLocksForKey
            }
            if let hold = holder(in: message, after: holdTakenMarker) {
                return .holdTaken(client: hold.client, pid: hold.pid)
            }
            if let hold = holder(in: message, after: holdClearedMarker) {
                return .holdCleared(client: hold.client, pid: hold.pid)
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
    public static func parse(_ line: Data, uid: UInt32? = nil) -> (time: Date, event: TouchIDEvent)? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let stamp = object["timestamp"] as? String, let time = time(stamp),
              let path = object["processImagePath"] as? String,
              let message = object["eventMessage"] as? String,
              let event = event(process: (path as NSString).lastPathComponent, message: message, uid: uid)
        else { return nil }
        return (time, event)
    }

    /// loginwindow posts the screen's lock and unlock with the session's user as the object
    /// (`with object:501`). A line naming another user is another session's; a line naming none is taken as
    /// this session's, so a macOS that stops writing the id costs nothing.
    private static func isThisSession(_ message: String, _ uid: UInt32?) -> Bool {
        guard let uid, let range = message.range(of: "with object:") else { return true }
        let digits = message[range.upperBound...].prefix { $0.isASCII && $0.isNumber }
        guard let object = UInt32(digits) else { return true }
        return object == uid
    }

    /// `<client>, with PID: <pid>` after `marker`. The client's name is whatever the holder calls itself,
    /// spaces and parentheses included, so the pid is read from the end.
    private static func holder(in message: String, after marker: String) -> (client: String, pid: Int32)? {
        guard let start = message.range(of: marker)?.upperBound else { return nil }
        let rest = message[start...]
        guard let pidRange = rest.range(of: ", with PID: ", options: .backwards),
              let pid = Int32(rest[pidRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return (String(rest[..<pidRange.lowerBound]), pid)
    }

    private static let stampFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        return formatter
    }()
}
