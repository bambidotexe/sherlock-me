import Foundation

/// The Health page: a table of checks that says whether the app works, and a table of readings.
///
/// A row's word comes from the shared vocabulary (`StatusWords`) wherever one fits; this table holds the
/// labels, the readings and the sentences that say how to put a row right. Console's own name for its crash
/// list is quoted from its loctable (`plutil -extract fr xml1` on
/// `/System/Applications/Utilities/Console.app/Contents/Resources/Localizable.loctable`), like a pane's.
///
/// TEMPLATE: an app's own rows add their labels and their fixes here, beside these.
public struct HealthPageStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: The two tables

    public var healthTitle: String {
        switch language {
        case .en: "Health"
        case .fr: "Santé"
        }
    }

    public var informationTitle: String {
        switch language {
        case .en: "Information"
        case .fr: "Informations"
        }
    }

    /// The Health table's one line when the app has nothing to check and nothing is wrong.
    public var everythingWorks: String {
        switch language {
        case .en: "Everything works"
        case .fr: "Tout fonctionne"
        }
    }

    public var checkAgainButton: String {
        switch language {
        case .en: "Check Again"
        case .fr: "Vérifier à nouveau"
        }
    }

    // MARK: The line every app adds while there is a crash

    public func crashesLabel(days: Int) -> String {
        switch language {
        case .en: "Crashes in the last \(days) days"
        case .fr: "Plantages ces \(days) derniers jours"
        }
    }

    public func lastCrash(_ stamp: String) -> String {
        switch language {
        case .en: "Last one \(stamp)"
        case .fr: "Le dernier le \(stamp)"
        }
    }

    public var crashesFix: String {
        switch language {
        case .en: "Console shows what happened, under “Crash Reports”."
        case .fr: "Console montre ce qui s'est passé, sous « Rapports de blocage »."
        }
    }

    // MARK: Readings

    public var runningForLabel: String {
        switch language {
        case .en: "Running for"
        case .fr: "En marche depuis"
        }
    }

    /// How long something has run, to the minute, in the two largest units that mean anything.
    public func duration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        switch language {
        case .en:
            if days > 0 { return "\(days) d \(hours) h" }
            if hours > 0 { return "\(hours) h \(minutes) min" }
            return minutes > 0 ? "\(minutes) min" : "Less than a minute"
        case .fr:
            if days > 0 { return "\(days) j \(hours) h" }
            if hours > 0 { return "\(hours) h \(minutes) min" }
            return minutes > 0 ? "\(minutes) min" : "Moins d'une minute"
        }
    }

    public var memoryLabel: String {
        switch language {
        case .en: "Memory used"
        case .fr: "Mémoire utilisée"
        }
    }

    public func megabytes(_ count: Int) -> String {
        switch language {
        case .en: "\(count) MB"
        case .fr: "\(count) Mo"
        }
    }
}
