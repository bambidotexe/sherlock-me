import Foundation

/// The onboarding wizard's three pages: the pitch, where the app lives, and "All set".
///
/// The window's own title is the app's name and is not a sentence, so it is not here.
///
/// TEMPLATE: the pitch and the last page are placeholders; a permission page's header, intro and rows go
/// between them, each row's title quoted from System Settings' own strings in both languages.
public struct OnboardingStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: The pitch

    public var pitchHeadline: String {
        switch language {
        case .en: "One small thing, done well."
        case .fr: "Une petite chose, bien faite."
        }
    }

    /// The one word of the headline drawn in the app's colour. Localized on its own, so the French accents
    /// its own word and not a fragment of another.
    public var pitchAccent: String {
        switch language {
        case .en: "well"
        case .fr: "bien"
        }
    }

    public var pitchBody: String {
        switch language {
        case .en: "\(AppIdentity.name) waits in the menu bar and stays out of the way. This page says what "
            + "it does, in two or three lines, before anything is asked of you."
        case .fr: "\(AppIdentity.name) attend dans la barre des menus et ne se met jamais en travers. Cette "
            + "page dit ce qu'il fait, en deux ou trois lignes, avant de vous demander quoi que ce soit."
        }
    }

    public var pitchMenuBarPill: String {
        switch language {
        case .en: "Menu bar"
        case .fr: "Barre des menus"
        }
    }

    public var pitchPrivatePill: String {
        switch language {
        case .en: "Nothing leaves your Mac"
        case .fr: "Rien ne quitte votre Mac"
        }
    }

    /// The tooltip and the accessibility description of the mark beside a row the app cannot work without.
    public var requiredMark: String {
        switch language {
        case .en: "Required"
        case .fr: "Requis"
        }
    }

    // MARK: Where it lives

    public var homeHeader: String {
        switch language {
        case .en: "Where it lives"
        case .fr: "Où il se trouve"
        }
    }

    public var homeIntro: String {
        switch language {
        case .en: "Neither of these is required. \(AppIdentity.name) has no window of its own and no "
            + "icon in the Dock: it waits in the menu bar. Both can be changed later in Settings."
        case .fr: "Facultatif. \(AppIdentity.name) n'a pas de fenêtre à lui ni d'icône dans le Dock : "
            + "il attend dans la barre des menus. Ces deux réglages sont modifiables plus tard dans les "
            + "réglages."
        }
    }

    /// **Exactly what the Login Items and Extensions pane calls the list the app appears in**, quoted from
    /// `LoginItems.appex`'s own strings.
    public var openAtLoginTitle: String {
        switch language {
        case .en: "Open at Login"
        case .fr: "Ouvrir avec la session"
        }
    }

    public var openAtLoginWhy: String {
        switch language {
        case .en: "Starts \(AppIdentity.name) when you log in, so it is there without opening anything. "
            + "It starts with no window."
        case .fr: "Lance \(AppIdentity.name) à l'ouverture de votre session, pour qu'il soit là sans rien "
            + "ouvrir. Il démarre sans fenêtre."
        }
    }

    public var menuBarWhy: String {
        switch language {
        case .en: "Its menu holds the way back to these settings. Hidden, \(AppIdentity.name) keeps "
            + "working: open it again from the Applications folder to get the window back."
        case .fr: "Son menu contient le chemin de retour vers ces réglages. Masquée, \(AppIdentity.name) "
            + "continue de fonctionner : rouvrez-le depuis le dossier Applications pour revenir à la fenêtre."
        }
    }

    public var turnOnButton: String {
        switch language {
        case .en: "Turn On"
        case .fr: "Activer"
        }
    }

    public var turnOffButton: String {
        switch language {
        case .en: "Turn Off"
        case .fr: "Désactiver"
        }
    }

    // MARK: All set

    public var doneHeadline: String {
        switch language {
        case .en: "All set"
        case .fr: "Tout est prêt"
        }
    }

    public var doneBody: String {
        switch language {
        case .en: "Look for \(AppIdentity.name) in the menu bar, at the top right, whenever you want to "
            + "change something."
        case .fr: "Retrouvez \(AppIdentity.name) dans la barre des menus, en haut à droite, pour changer "
            + "un réglage."
        }
    }

    // MARK: The stepping button

    public var continueButton: String {
        switch language {
        case .en: "Continue"
        case .fr: "Continuer"
        }
    }

    /// What the stepping button reads until the page's own rule is met.
    public var skipButton: String {
        switch language {
        case .en: "Skip"
        case .fr: "Passer"
        }
    }

    public var finishButton: String {
        switch language {
        case .en: "Finish"
        case .fr: "Terminer"
        }
    }
}
