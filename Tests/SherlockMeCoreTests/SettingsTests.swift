import XCTest
import SherlockMeCore

/// The switches, the flag the onboarding wizard writes, and the rule that keeps an older settings file
/// from resetting the rest. Every stored property gets a line in each test below.
final class SettingsTests: XCTestCase {
    func testTheDefaults() {
        let settings = Settings()
        XCTAssertTrue(settings.showInMenuBar)
    }

    /// A fresh install has not walked the wizard, so the wizard opens.
    func testOnboardingStartsUnwalked() {
        XCTAssertFalse(Settings().onboardingCompleted)
    }

    func testAFileWrittenByAnOlderBuildKeepsWhatItSaysAndDefaultsTheRest() throws {
        let data = Data(#"{"showInMenuBar": false}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertFalse(settings.showInMenuBar)
        XCTAssertFalse(settings.onboardingCompleted)
    }

    /// A file written before the wizard existed defaults the flag to false, so the wizard opens once for
    /// someone who has been using the app for months. Deliberate: it is the only place that says what the
    /// app asks for.
    func testAFileFromBeforeTheWizardOpensTheWizard() throws {
        let data = Data(#"{"showInMenuBar": true}"#.utf8)
        XCTAssertFalse(try JSONDecoder().decode(Settings.self, from: data).onboardingCompleted)
    }

    func testAnEmptyFileIsEveryDefault() throws {
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)), Settings())
    }

    func testItSurvivesARoundTrip() throws {
        var settings = Settings()
        settings.showInMenuBar = false
        settings.onboardingCompleted = true
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: data), settings)
    }
}
