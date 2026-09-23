import Foundation

/// Everything the Health page reports, as values. The app gathers them (`Platform` reads the system, `App`
/// reads its own state); this layer turns them into the page's two tables, so what a fact reads as, in which
/// colour and with which sentence, is decided here and tested.
public struct HealthFacts: Equatable, Sendable {
    /// Whether SherlockMe can see the Touch ID key.
    public var watcher: WatcherState
    /// How long ago the Touch ID key last locked the Mac, and the last unwanted unlock was caught; nil
    /// before the first.
    public var sinceLastLock: TimeInterval?
    public var sinceLastRelock: TimeInterval?
    /// When each crash report of this app in the last `K.healthCrashWindow` was written, newest first.
    public var recentCrashes: [Date]

    public init(watcher: WatcherState, sinceLastLock: TimeInterval?, sinceLastRelock: TimeInterval?,
                recentCrashes: [Date]) {
        self.watcher = watcher
        self.sinceLastLock = sinceLastLock
        self.sinceLastRelock = sinceLastRelock
        self.recentCrashes = recentCrashes
    }
}

/// The Health page's two tables: the checks, green, orange or red, and the readings, blue.
///
/// **A check is something that has to be in place or running for the app to work**: a permission, a setup
/// the onboarding asks for (a hook, a rule, an agent), the service or the sensor the feature rests on. A
/// preference is never a check, whichever way it is set (Launch at login, a feature's own switch, a macOS
/// setting that does not stop the app), and neither is a reading. The skill
/// `macos-building-settings-pages` (*The Health page*) holds the rules and every app's list.
public enum HealthReport {
    /// The Health table, in page order: the one mechanism SherlockMe rests on, always there, then the
    /// crashes while there are some. SherlockMe asks for no permission and sets nothing up, so there is no
    /// grant line.
    public static func checks(for facts: HealthFacts) -> [HealthRow] {
        [watching(facts.watcher), crashes(facts.recentCrashes)].compactMap { $0 }
    }

    /// The Information table: when each of the two things SherlockMe does last happened, *None yet* until
    /// the first. Nothing on an account that cannot read the log, where SherlockMe does nothing.
    public static func readings(for facts: HealthFacts) -> [InfoRow] {
        guard facts.watcher != .needsAdministrator else { return [] }
        let t = Loc.settings.health
        return [
            InfoRow(id: "last lock", label: t.lastLockLabel,
                    value: facts.sinceLastLock.map { t.ago(seconds: $0) } ?? t.noneYet),
            InfoRow(id: "last relock", label: t.lastRelockLabel,
                    value: facts.sinceLastRelock.map { t.ago(seconds: $0) } ?? t.noneYet),
        ]
    }

    /// Watching the Touch ID key: one line whatever stops it (one cause, one line), green while the log is
    /// read, red while it is not, with the fix that matches the cause.
    public static func watching(_ state: WatcherState) -> HealthRow {
        let t = Loc.settings.health
        switch state {
        case .watching:
            return HealthRow(id: "touch id key", label: t.watchingLabel, level: .good, word: t.running)
        case .stopped:
            return HealthRow(id: "touch id key", label: t.watchingLabel, level: .failure, word: t.stopped,
                             fix: t.stoppedFix)
        case .needsAdministrator:
            return HealthRow(id: "touch id key", label: t.watchingLabel, level: .failure, word: t.stopped,
                             fix: t.needsAdministratorFix)
        }
    }

    /// The line every app of the family ends its Health table with, **only while there is a crash** in the
    /// last `K.healthCrashWindow`: a crash is a problem while it is recent, and no crash is nothing to say.
    public static func crashes(_ recentCrashes: [Date]) -> HealthRow? {
        guard let last = recentCrashes.first else { return nil }
        let t = Loc.settings.health
        return HealthRow(id: "crashes", label: t.crashesLabel(days: Int(K.healthCrashWindow / 86_400)),
                         level: .warning, word: "\(recentCrashes.count)", detail: t.lastCrash(stamp(last)),
                         fix: t.crashesFix)
    }

    /// A moment as a tooltip wants it: the same in every language, sortable, to the minute, in the Mac's own
    /// time zone.
    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
