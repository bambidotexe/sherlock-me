import Foundation

/// The Health page: a table of checks that says whether the app works, and a table of readings.
///
/// A row's word comes from the shared vocabulary (`StatusWords`) wherever one fits; this table holds the
/// labels, the readings and the sentences that say how to put a row right. Console's own name for its crash
/// list is quoted from its loctable (`plutil -extract fr xml1` on
/// `/System/Applications/Utilities/Console.app/Contents/Resources/Localizable.loctable`), like a pane's, and so
/// are the Users & Groups pane and its switch (`UsersGroups.appex`, `InfoPlist.loctable` and
/// `Localizable.loctable`).
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

    public var checkAgainButton: String {
        switch language {
        case .en: "Check Again"
        case .fr: "Vérifier à nouveau"
        }
    }

    // MARK: Watching the Touch ID key

    public var watchingLabel: String {
        switch language {
        case .en: "Watching the Touch ID key"
        case .fr: "Surveillance de la touche Touch ID"
        }
    }

    public var running: String {
        switch language {
        case .en: "Running"
        case .fr: "En marche"
        }
    }

    public var stopped: String {
        switch language {
        case .en: "Stopped"
        case .fr: "Arrêtée"
        }
    }

    /// The log stream ended, and is started again by itself.
    public var stoppedFix: String {
        switch language {
        case .en: "\(AppIdentity.name) starts it again by itself, and until then the Touch ID key locks the Mac "
            + "the way macOS does. If this stays red, quit \(AppIdentity.name) and open it again."
        case .fr: "\(AppIdentity.name) la relance tout seul, et d'ici là la touche Touch ID verrouille le Mac "
            + "comme le fait macOS. Si cette ligne reste rouge, quittez \(AppIdentity.name) et rouvrez-le."
        }
    }

    /// The account is not an administrator, which only an administrator can change.
    public var needsAdministratorFix: String {
        switch language {
        case .en: "Only an administrator account can see the Touch ID key, and on this one the key locks the Mac "
            + "the way macOS does. In System Settings › Users & Groups, an administrator can turn on "
            + "“Allow this user to administer this computer” for this account."
        case .fr: "Seul un compte administrateur peut voir la touche Touch ID, et sur celui-ci la touche "
            + "verrouille le Mac comme le fait macOS. Dans Réglages Système › Utilisateurs et groupes, un "
            + "administrateur peut activer « Autoriser cet utilisateur à administrer cet ordinateur » pour ce "
            + "compte."
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

    public var lastLockLabel: String {
        switch language {
        case .en: "Last lock with the Touch ID key"
        case .fr: "Dernier verrouillage par la touche Touch ID"
        }
    }

    public var lastRelockLabel: String {
        switch language {
        case .en: "Last unlock caught"
        case .fr: "Dernier déverrouillage rattrapé"
        }
    }

    /// A reading with nothing to show yet.
    public var noneYet: String {
        switch language {
        case .en: "None yet"
        case .fr: "Aucun pour l'instant"
        }
    }

    /// How long ago something happened, in the two largest units that mean anything.
    public func ago(seconds: TimeInterval) -> String {
        if seconds < 60 {
            switch language {
            case .en: return "Just now"
            case .fr: return "À l'instant"
            }
        }
        switch language {
        case .en: return "\(duration(seconds: seconds)) ago"
        case .fr: return "Il y a \(duration(seconds: seconds))"
        }
    }

    /// How long something lasted, to the minute, in the two largest units that mean anything.
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
}
