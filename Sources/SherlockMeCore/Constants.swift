import Foundation

/// Every number the app is built on, once, with the evidence for it beside it. A number that is a matter of
/// taste is not here and is not offered as a setting either: it is a rule.
public enum K {
    // MARK: - The Touch ID key

    /// A read of the sensor that begins this long after the lock is not the lock screen's. Measured: the lock
    /// screen starts reading 0.03 to 0.15 s after the screen locked, which comes 0.1 to 0.4 s after the key.
    public static let readAfterLock: TimeInterval = 3

    /// A finger seen this soon after the read began was already on the sensor: the finger that pressed the
    /// key, resting. Measured on the owner's presses: resting fingers 0.001 to 0.42 s into the read,
    /// deliberate touches 0.97 s and later (the owner's log, runs 1, 1b, 4, 7, 8, 9).
    public static let restingFinger: TimeInterval = 0.5

    /// A finger that leaves this soon after it was seen was the key coming up, not a finger resting.
    /// Measured: 17 ms (run 4).
    public static let keyBlip: TimeInterval = 0.1

    /// When the resting finger is the one that unlocked, the unlock comes this soon after it leaves: the
    /// match lands 0.2 to 0.25 s after the finger that gave the image leaves. A later unlock was another touch.
    public static let matchAfterLift: TimeInterval = 0.5

    /// An unlock this soon after the lock the rule follows may be undone. Every unwanted unlock came 0.9 to
    /// 1.6 s after the press.
    public static let relockWindow: TimeInterval = 6

    /// How long after the unwanted unlock the Mac is locked again. At once, the desktop showed for 0.10 to
    /// 0.12 s and the relocked screen stayed on the wallpaper with no login box until a key was pressed
    /// (run 7). After 1 s, a normal lock screen, and the Mac unlocked for 1.16 to 1.19 s (run 8). After
    /// 0.5 s, a normal lock screen, unlocked for 0.61 to 0.64 s (run 9): the owner's choice.
    public static let relockDelay: TimeInterval = 0.5

    /// Relocks per press. In 23 relocks (runs 7 to 9) not one Mac unlocked by itself afterwards, so a second
    /// one could only undo a deliberate unlock.
    public static let relocksPerPress = 1

    /// loginwindow's own lock on the key belongs to the press whose key line came this soon before it.
    /// Measured: loginwindow hears of the key 0.305 to 0.321 s after it goes down (ten presses).
    public static let sameKeyPress: TimeInterval = 1

    /// The waits before `log stream` is started again after it ended, by how many times in a row it has
    /// ended; the last one repeats. Not measured: the stream never ended in any run. They keep a stream that
    /// cannot start from being started again in a tight loop, and bring a working one back within a second.
    public static let watchRestartDelays: [TimeInterval] = [1, 5, 30, 60]

    /// A stream that ran this long before it ended was working: its end starts the waits over.
    public static let watchSteadyAfter: TimeInterval = 60

    /// How long after `log stream` starts the rule takes the window server's word for a lock the stream may
    /// not have shown: a stream shows nothing logged before it attached. Not measured: it leaves the stream
    /// room to attach, and a lock so soon after a start is rare.
    public static let watchSettle: TimeInterval = 2

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
