import XCTest
import SherlockMeCore
@testable import SherlockMePlatform

/// The store persists on every change and loads what is on disk as it is.
@MainActor
final class SettingsStoreTests: XCTestCase {
    /// One domain for the whole class, emptied before and after each test. A fresh name per test would leave
    /// a plist behind for every test ever run: `cfprefsd` keeps a domain's file once it has been made, even
    /// emptied (the shared pitfalls, *Tooling and tests*).
    private static let suite = "sherlockme.tests.settings-store"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suite)
        defaults.removePersistentDomain(forName: Self.suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suite)
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
