import Foundation

/// The System page: what the app needs from macOS, and whether it has it.
///
/// TEMPLATE: a permission's group is a title, a hint saying what the app does with it, a note reassuring
/// about what never leaves the Mac, a warning quoting the switch **as the Privacy and Security pane names
/// it** (read it again with `plutil -extract fr xml1` after a macOS release), the row's own name, and the
/// button that opens the pane.
public struct SystemPageStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: Start over

    public var startOverTitle: String {
        switch language {
        case .en: "Start over"
        case .fr: "Recommencer"
        }
    }

    public var showOnboardingButton: String {
        switch language {
        case .en: "Show Onboarding Again"
        case .fr: "Revoir la présentation"
        }
    }
}
