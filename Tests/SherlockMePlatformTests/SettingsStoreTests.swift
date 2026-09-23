import XCTest
import SherlockMeCore
@testable import SherlockMePlatform

/// The store persists on every change and loads what is on disk as it is.
@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "sherlockme.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAFreshStoreHoldsTheDefaults() {
        XCTAssertEqual(SettingsStore(defaults: defaults).settings, Settings())
    }

    func testAChangeIsWrittenAndReadBack() {
        let store = SettingsStore(defaults: defaults)
        store.settings.showInMenuBar = false
        store.settings.onboardingCompleted = true
        let again = SettingsStore(defaults: defaults)
        XCTAssertFalse(again.settings.showInMenuBar)
        XCTAssertTrue(again.settings.onboardingCompleted)
    }

    /// What is on disk is loaded as it is: a value the user set is never moved by a default that changed
    /// in code (the shared pitfalls, *A persisted default is not a default*).
    func testAnUnreadableBlobFallsBackToTheDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsStore.defaultsKey)
        XCTAssertEqual(SettingsStore(defaults: defaults).settings, Settings())
    }
}
