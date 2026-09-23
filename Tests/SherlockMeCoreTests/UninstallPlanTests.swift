import XCTest
import SherlockMeCore

/// What the uninstall's detached helper is told to remove, and how it quotes what it is given.
final class UninstallPlanTests: XCTestCase {
    private func script(home: String = "/Users/someone") -> String {
        UninstallPlan.helperScript(pid: 4_242, supportDirectory: "\(home)/Library/Application Support/SherlockMe",
                                   bundleIdentifier: "dev.rubens.SherlockMe", home: home)
    }

    func testItWaitsForTheAppToGoBeforeItTouchesAnything() {
        let text = script()
        let wait = try? XCTUnwrap(text.split(separator: "\n").first { $0.hasPrefix("while") })
        XCTAssertNotNil(wait)
        XCTAssertTrue(text.contains("/bin/kill -0 4242"))
        // The wait is bounded: a helper that could spin for ever is worse than one that stops.
        XCTAssertTrue(text.contains("-lt \(UninstallPlan.helperWaitTenths)"))
    }

    func testThePreferencesAreDroppedBeforeTheFileIsRemoved() {
        let text = script()
        guard let defaults = text.range(of: "/usr/bin/defaults delete"),
              let remove = text.range(of: "/bin/rm -rf") else { return XCTFail("both steps are missing") }
        // cfprefsd writes its cache back over the gap otherwise.
        XCTAssertTrue(defaults.lowerBound < remove.lowerBound)
    }

    func testEverythingNamedAfterTheBundleIdentifierGoes() {
        let text = script()
        for path in ["Library/Application Support/SherlockMe",
                     "Library/Preferences/dev.rubens.SherlockMe.plist",
                     "Library/Caches/dev.rubens.SherlockMe",
                     "Library/HTTPStorages/dev.rubens.SherlockMe",
                     "Library/Saved Application State/dev.rubens.SherlockMe.savedState"] {
            XCTAssertTrue(text.contains(path), path)
        }
        XCTAssertTrue(text.contains("Preferences/ByHost"))
    }

    func testAHomeFolderWithAQuoteInItIsStillQuotedSafely() {
        let text = script(home: "/Users/it's mine")
        XCTAssertTrue(text.contains("'/Users/it'\\''s mine/Library/Preferences/dev.rubens.SherlockMe.plist'"),
                      text)
    }

    func testTheQuotingCloseAndReopensAroundEveryQuote() {
        XCTAssertEqual(UninstallPlan.shellQuoted("/a/b"), "'/a/b'")
        XCTAssertEqual(UninstallPlan.shellQuoted("/a'b"), "'/a'\\''b'")
    }

    func testWhatIsLeftToCheckAfterwards() {
        let remains = UninstallPlan.remains(bundlePath: "/Applications/SherlockMe.app",
                                            bundleIdentifier: "dev.rubens.SherlockMe",
                                            supportDirectory: "/Users/x/Library/Application Support/SherlockMe")
        XCTAssertEqual(remains.count, 3)
    }
}
