import Foundation

/// Everything the user can choose, and the one thing the app remembers about them.
///
/// Stored as one JSON blob in `UserDefaults` by `SherlockMePlatform.SettingsStore`. Every property has a
/// default here and is decoded tolerantly, so a settings file written by an older build never resets the
/// rest of it. A value the system owns (the login item) is never mirrored here: it is read from the system
/// every time.
///
/// TEMPLATE: a user-facing setting is a stored property here and a control in the Settings window; every
/// other number is a `static let` in `Constants.swift`, deliberately not reachable by `defaults write`.
/// `SettingsTests` pins the roster.
public struct Settings: Codable, Equatable, Sendable {
    /// The menu-bar item. Hiding it leaves the app working; opening the bundle again is the way back to
    /// the Settings window.
    public var showInMenuBar: Bool = true

    /// Whether the last page of the onboarding wizard has been reached and its button pressed. Not a
    /// setting: no window shows it, and Settings > System offers the wizard again rather than this flag. A
    /// wizard closed before that last button keeps it false, so it opens again at the next launch.
    public var onboardingCompleted: Bool = false

    public init() {}

    /// Written out rather than synthesised: a key missing from an older file has to fall back to its
    /// default instead of failing the whole decode, which would throw away the others.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar)
            ?? fallback.showInMenuBar
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
            ?? fallback.onboardingCompleted
    }
}
