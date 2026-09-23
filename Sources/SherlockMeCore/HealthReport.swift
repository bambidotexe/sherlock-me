import Foundation

/// Everything the Health page reports, as values. The app gathers them (`Platform` reads the system, `App`
/// reads its own state); this layer turns them into the page's two tables, so what a fact reads as, in which
/// colour and with which sentence, is decided here and tested.
///
/// TEMPLATE: the app's own facts go here, each a plain value: a permission is a `Bool` read with the
/// permission's reader, a service is what it last reported, a reading is a number or an optional date.
public struct HealthFacts: Equatable, Sendable {
    /// How long this process has been running, nil when the system would not say.
    public var runningSeconds: TimeInterval?
    /// The memory this process holds, as Activity Monitor counts it; nil when the system would not say.
    public var memoryBytes: UInt64?
    /// When each crash report of this app in the last `K.healthCrashWindow` was written, newest first.
    public var recentCrashes: [Date]

    public init(runningSeconds: TimeInterval?, memoryBytes: UInt64?, recentCrashes: [Date]) {
        self.runningSeconds = runningSeconds
        self.memoryBytes = memoryBytes
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
    /// The Health table, in page order.
    ///
    /// TEMPLATE: the app's own checks go first, one line each and always there: every permission and every
    /// setup the onboarding asks for (`HealthRules.grant(held:required:)`, with the wizard's own
    /// `required`), then the service or the sensor the feature rests on. A check that has nothing to say
    /// while things are fine (a flag that must hold while armed, a list that could not be read) is a line
    /// only while it is wrong. Then `crashes`. `HealthLimits.checks` is the ceiling, with everything that
    /// can go wrong gone wrong at once.
    public static func checks(for facts: HealthFacts) -> [HealthRow] {
        [crashes(facts.recentCrashes)].compactMap { $0 }
    }

    /// The Information table, in page order.
    ///
    /// TEMPLATE: replace these with what is worth knowing about the app's own job, at most
    /// `HealthLimits.readings`: the last time the thing it watches happened, the value its sensor reads,
    /// what it is doing right now. Keep *Running for* and *Memory used* only when the app has nothing
    /// better to say.
    public static func readings(for facts: HealthFacts) -> [InfoRow] {
        let t = Loc.settings.health
        var rows: [InfoRow] = []
        if let seconds = facts.runningSeconds {
            rows.append(InfoRow(id: "running for", label: t.runningForLabel, value: t.duration(seconds: seconds)))
        }
        if let bytes = facts.memoryBytes {
            rows.append(InfoRow(id: "memory", label: t.memoryLabel,
                                value: t.megabytes(Int((Double(bytes) / 1_048_576).rounded()))))
        }
        return rows
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
