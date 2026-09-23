import Foundation

/// The menu-bar menu. `MenuBarController` rebuilds it from scratch on every open and reads these then, so
/// the menu is never a language or a state behind.
///
/// SherlockMe has no switch of its own, so its one line of its own is the read-only status line.
public struct MenuStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: What SherlockMe is doing

    /// The read-only line for what the watcher is doing right now.
    public func status(_ state: WatcherState) -> String {
        switch state {
        case .watching: watching
        case .stopped: stoppedStartingAgain
        case .needsAdministrator: needsAdministrator
        }
    }

    public var watching: String {
        switch language {
        case .en: "Watching the Touch ID key"
        case .fr: "Touche Touch ID surveillée"
        }
    }

    public var stoppedStartingAgain: String {
        switch language {
        case .en: "Touch ID key not watched: starting again"
        case .fr: "Touche Touch ID non surveillée : redémarrage"
        }
    }

    public var needsAdministrator: String {
        switch language {
        case .en: "Touch ID key not watched: not an administrator"
        case .fr: "Touche Touch ID non surveillée : compte non administrateur"
        }
    }

    // MARK: The items every app has

    public var launchAtLogin: String {
        switch language {
        case .en: "Launch at Login"
        case .fr: "Lancer à la connexion"
        }
    }

    public var settings: String {
        switch language {
        case .en: "Settings…"
        case .fr: "Réglages…"
        }
    }

    public var quit: String {
        switch language {
        case .en: "Quit \(AppIdentity.name)"
        case .fr: "Quitter \(AppIdentity.name)"
        }
    }
}
