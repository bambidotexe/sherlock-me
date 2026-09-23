import Foundation

/// The menu-bar menu. `MenuBarController` rebuilds it from scratch on every open and reads these then, so
/// the menu is never a language or a state behind.
///
/// TEMPLATE: the feature's own items and the read-only status lines go here too, one accessor each.
public struct MenuStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

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
