import Foundation

/// Whether SherlockMe can see the Touch ID key: what the menu's status line and the Health page report.
public enum WatcherState: Equatable, Sendable {
    /// `log stream` runs and its lines reach the rule.
    case watching
    /// The stream ended or could not start, and starts again after `WatchRestart.delay`. Meanwhile the key
    /// does what macOS makes it do.
    case stopped
    /// This account is not an administrator and cannot read the log: nothing is started, and the key does
    /// what macOS makes it do.
    case needsAdministrator
}

/// When a stream that ended is started again.
public enum WatchRestart {
    /// The wait before starting the stream again, after it has ended `failures` times in a row (1 for the
    /// first): `K.watchRestartDelays`, the last one repeated.
    public static func delay(afterFailures failures: Int) -> TimeInterval {
        let delays = K.watchRestartDelays
        return delays[min(max(failures, 1), delays.count) - 1]
    }

    /// How many ends in a row this one makes. A stream that ran `K.watchSteadyAfter` or longer was working,
    /// so its end is the first of a new run.
    public static func failures(previous: Int, ranFor seconds: TimeInterval) -> Int {
        seconds >= K.watchSteadyAfter ? 1 : previous + 1
    }
}
