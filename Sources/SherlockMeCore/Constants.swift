import Foundation

/// Every number the app is built on, once, with the evidence for it beside it. A number that is a matter of
/// taste is not here and is not offered as a setting either: it is a rule.
///
/// TEMPLATE: the app's own numbers go above the update's, each with the measurement that chose it.
public enum K {
    // MARK: - Updates

    /// How long after launch the first check nobody asked for is made. Late enough that it never competes
    /// with the launch itself.
    public static let updateLaunchDelay: TimeInterval = 20

    /// How often the schedule is looked at. Coarse on purpose: the app holds one repeating timer and asks
    /// at every wake as well, so a Mac that slept through the date is asked as soon as it is awake.
    public static let updateTick: TimeInterval = 60 * 30

    /// A week between two checks that got an answer, whoever asked.
    public static let updateInterval: TimeInterval = 7 * 24 * 60 * 60

    /// A check that could not reach GitHub is tried again at the first tick an hour or more later.
    public static let updateRetryDelay: TimeInterval = 60 * 60

    public static let updateCheckTimeout: TimeInterval = 15

    /// How long the app waits for its own quit after Install and Relaunch before it stops the helper and
    /// says so. Shorter than the helper's own `updateQuitWait`, so the helper's limit only ever serves an
    /// app too hung to stop it.
    public static let updateStallNotice: TimeInterval = 8

    /// Seconds the helper waits for the app to quit, for the new version to show among the running
    /// processes, and how long after that it looks once more.
    public static let updateQuitWait = 30
    public static let updateLaunchWait = 20
    public static let updateSettle = 3

    /// Past this, an install result was left behind by an install nobody is waiting on any more, and it
    /// opens no window.
    public static let updateResultShelfLife: TimeInterval = 10 * 60

    // MARK: - Windows

    /// How often the Settings window re-reads what it does not own: the login item, and a permission in an
    /// app that has one. Slow enough to be free, fast enough that flipping a switch in System Settings and
    /// coming back finds the page already right. Started and stopped by the window, never by a view's
    /// `onAppear`.
    public static let systemPollInterval: TimeInterval = 2

    /// How often the onboarding wizard re-reads the rows on its page, and tells the app that a grant may
    /// have arrived. Slow enough to be free, fast enough that granting in System Settings and coming back
    /// finds the row already right. **The app's only poll**: the wizard starts it when it opens and stops it
    /// when it closes, and nothing else watches a grant on a timer.
    public static let onboardingPollInterval: TimeInterval = 2

    /// How long a wait for another app to quit stays honoured, after a row's button has sent the user to
    /// System Settings. Long enough to grant a permission, short enough that an unrelated visit there much
    /// later does not pull the wizard forward out of nowhere.
    public static let focusReturnWait: TimeInterval = 300

    // MARK: - Health

    /// How far back the Health page counts crash reports. A week covers the gap between two weekly update
    /// checks, and a crash older than that has either been fixed by a release or been seen again since.
    public static let healthCrashWindow: TimeInterval = 7 * 24 * 60 * 60

    /// The shortest time Check Again shows its spinner. Most checks answer in a few milliseconds, and a
    /// spinner that goes before it can be seen reads as a button that did nothing; half a second is seen and
    /// does not keep anyone waiting.
    public static let healthMinimumBusy: TimeInterval = 0.5
}
