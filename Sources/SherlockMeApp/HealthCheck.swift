import SherlockMeCore
import SherlockMePlatform
import Foundation

/// The readings only the Health page shows: how long the app has been up, what it holds and its crashes.
/// What the rest of the window also shows (a permission) is `SystemStatus`'s, polled every 2 s while the window is open; these are read when the page is shown and
/// when Check Again is pressed, and never on a timer, so a page nobody is looking at costs nothing.
///
/// **The window drives this, not a view**, like `SystemStatus`: `SettingsWindow` reads it when it opens on
/// the Health page and when the page is picked.
///
/// TEMPLATE: a reading of the app's own that is not polled (the last time the feature acted, a service's
/// answer) is read here too. One that is slow or waits on anything (a socket, a subprocess, the network) is
/// read off the main thread, and Check Again keeps its spinner until it lands.
@MainActor
final class HealthCheck: ObservableObject {
    struct Readings: Equatable {
        var runningSeconds: TimeInterval?
        var memoryBytes: UInt64?
        var recentCrashes: [Date] = []
    }

    @Published private(set) var readings = Readings()
    /// True from a press of Check Again until its readings have landed, and for at least
    /// `K.healthMinimumBusy`.
    @Published private(set) var isChecking = false

    /// Everything the page reports, the polled states from `status` and the rest from here.
    func facts(_ status: SystemStatus) -> HealthFacts {
        HealthFacts(runningSeconds: readings.runningSeconds, memoryBytes: readings.memoryBytes,
                    recentCrashes: readings.recentCrashes)
    }

    /// Reads everything again. Cheap: a sysctl, a task_info and a directory listing.
    func read() {
        let now = Date()
        let process = Bundle.main.executableURL?.lastPathComponent ?? AppIdentity.name
        let fresh = Readings(
            runningSeconds: ProcessStats.launchDate.map { now.timeIntervalSince($0) },
            memoryBytes: ProcessStats.memoryFootprint,
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
