import Foundation

/// The System page: what the app needs from macOS, and whether it has it. SherlockMe asks for no permission,
/// so the page holds only Start over.
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
