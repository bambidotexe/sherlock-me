import os
import SherlockMeCore

/// The app's logging surface, deliberately small: what is otherwise invisible, and nothing per event.
/// A chatty logger is one nobody reads.
///
/// `/usr/bin/log show --predicate 'subsystem == "<bundle identifier>"' --last 1h`
/// (`log` alone is a zsh builtin, hence the full path). Anything that declines to act logs why, once,
/// with the numbers: silence is a defect.
public enum Log {
    /// Launch, the settings window, the menu bar.
    public static let app = Logger(subsystem: AppIdentity.logSubsystem, category: "app")
    /// Every check, what it found, the fetch, the unpacking and the hand-over to the install helper.
    public static let update = Logger(subsystem: AppIdentity.logSubsystem, category: "update")
    /// The onboarding wizard: the poll, the stepping button's word, and at `debug` where that button
    /// actually is. A button drawn in one place and hit-tested in another says nothing on its own, and this
    /// is the line that shows it (the shared pitfalls, *Onboarding*).
    public static let onboarding = Logger(subsystem: AppIdentity.logSubsystem, category: "onboarding")
    /// The Touch ID key: the log stream starting, ending and starting again, every lock and relock with
    /// loginwindow's answer, every unlock left alone and why, and at `debug` every line the rule was given.
    public static let touchID = Logger(subsystem: AppIdentity.logSubsystem, category: "touchid")
}
