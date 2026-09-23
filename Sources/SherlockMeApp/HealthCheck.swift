import SherlockMeCore
import SherlockMePlatform
import Foundation

/// The readings only the Health page shows: whether the Touch ID key is watched, when it last locked the Mac
/// and when an unwanted unlock was last caught, and the app's crashes. What the rest of the window also shows
/// (the login item) is `SystemStatus`'s, polled every 2 s while the window is open; these are read when the
/// page is shown and when Check Again is pressed, and never on a timer, so a page nobody is looking at costs
/// nothing.
///
/// **The window drives this, not a view**, like `SystemStatus`: `SettingsWindow` reads it when it opens on
/// the Health page and when the page is picked.
@MainActor
final class HealthCheck: ObservableObject {
    struct Readings: Equatable {
        var watcher: WatcherState = .stopped
        var sinceLastLock: TimeInterval?
        var sinceLastRelock: TimeInterval?
        var recentCrashes: [Date] = []
    }

    @Published private(set) var readings = Readings()
    /// True from a press of Check Again until its readings have landed, and for at least
    /// `K.healthMinimumBusy`.
    @Published private(set) var isChecking = false

    /// Everything the page reports, the polled states from `status` and the rest from here.
    func facts(_ status: SystemStatus) -> HealthFacts {
        HealthFacts(watcher: readings.watcher, sinceLastLock: readings.sinceLastLock,
                    sinceLastRelock: readings.sinceLastRelock, recentCrashes: readings.recentCrashes)
    }

    /// Reads everything again. Cheap: a copy taken under a lock and a directory listing.
    func read() {
        let now = Date()
        let process = Bundle.main.executableURL?.lastPathComponent ?? AppIdentity.name
        let touchID = TouchIDGuard.shared.status
        let fresh = Readings(
            watcher: touchID.watcher,
            sinceLastLock: touchID.lastLock.map { now.timeIntervalSince($0) },
            sinceLastRelock: touchID.lastRelock.map { now.timeIntervalSince($0) },
            recentCrashes: CrashReports.recent(process: process, since: now.addingTimeInterval(-K.healthCrashWindow)))
        if fresh != readings { readings = fresh }
    }

    /// Check Again: every reading now, the polled states with them, and a spinner beside the button long
    /// enough to be seen.
    func checkAgain(_ status: SystemStatus) {
        guard !isChecking else { return }
        isChecking = true
        status.refresh()
        read()
        DispatchQueue.main.asyncAfter(deadline: .now() + K.healthMinimumBusy) { [weak self] in
            self?.isChecking = false
        }
    }
}
