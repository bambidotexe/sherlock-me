import XCTest
@testable import SherlockMeCore

/// The Health page's rules: which colour a check takes, which lines every app adds while they are wrong,
/// how long the two tables may grow, and which files are this app's crash reports.
final class HealthTests: XCTestCase {
    override func tearDown() {
        Loc.language = .en
        super.tearDown()
    }

    private func facts(_ watcher: WatcherState = .watching, lastLock: TimeInterval? = 125,
                       lastRelock: TimeInterval? = nil, crashes: [Date] = []) -> HealthFacts {
        HealthFacts(watcher: watcher, sinceLastLock: lastLock, sinceLastRelock: lastRelock, recentCrashes: crashes)
    }

    // MARK: Levels

    func testAMissingGrantIsRedOnlyWhenTheWizardMarksItRequired() {
        XCTAssertEqual(HealthRules.grant(held: true, required: true), .good)
        XCTAssertEqual(HealthRules.grant(held: true, required: false), .good)
        XCTAssertEqual(HealthRules.grant(held: false, required: true), .failure)
        XCTAssertEqual(HealthRules.grant(held: false, required: false), .warning)
    }

    func testAFixIsShownOnlyWhileItsRowIsOrangeOrRed() {
        let fine = HealthRow(id: "a", label: "A", level: .good, word: "x", fix: "Do this.")
        let wrong = HealthRow(id: "b", label: "B", level: .warning, word: "x", fix: "Do that.")
        let twice = HealthRow(id: "c", label: "C", level: .failure, word: "x", fix: "Do that.")
        XCTAssertEqual([fine, wrong, twice].warnings, ["Do that."])
        XCTAssertEqual([fine].warnings, [])
    }

    // MARK: Watching the Touch ID key

    func testWatchingTheKeyIsGreen() {
        let checks = HealthReport.checks(for: facts())
        XCTAssertEqual(checks.map(\.id), ["touch id key"])
        XCTAssertEqual(checks.first?.level, .good)
        XCTAssertEqual(checks.first?.word, "Running")
        XCTAssertEqual(checks.warnings, [])
    }

    func testAStoppedStreamIsRedAndSaysItComesBack() {
        let checks = HealthReport.checks(for: facts(.stopped))
        XCTAssertEqual(checks.first?.level, .failure)
        XCTAssertEqual(checks.first?.word, "Stopped")
        XCTAssertEqual(checks.warnings, [Loc.settings.health.stoppedFix])
    }

    func testAnAccountThatCannotReadTheLogIsRedAndSaysWhoCanChangeThat() {
        let checks = HealthReport.checks(for: facts(.needsAdministrator))
        XCTAssertEqual(checks.first?.level, .failure)
        XCTAssertEqual(checks.warnings, [Loc.settings.health.needsAdministratorFix])
        XCTAssertEqual(HealthReport.readings(for: facts(.needsAdministrator)), [])
    }

    // MARK: The tables

    func testTheReadings() {
        XCTAssertEqual(HealthReport.readings(for: facts()).map(\.value), ["2 min ago", "None yet"])
        XCTAssertEqual(HealthReport.readings(for: facts(lastLock: nil, lastRelock: 30)).map(\.value),
                       ["None yet", "Just now"])
    }

    func testACrashIsALineOnlyWhileThereIsOne() {
        let crash = Date(timeIntervalSince1970: 1_790_000_000)
        let checks = HealthReport.checks(for: facts(crashes: [crash]))
        XCTAssertEqual(checks.map(\.id), ["touch id key", "crashes"])
        XCTAssertEqual(checks.last?.level, .warning)
        XCTAssertEqual(checks.last?.word, "1")
        XCTAssertEqual(checks.last?.detail, "Last one \(HealthReport.stamp(crash))")
        XCTAssertEqual(checks.warnings, [Loc.settings.health.crashesFix])
    }

    func testTheTablesStayShortInTheWorstCase() {
        let worst = facts(.stopped, lastLock: 60, lastRelock: 60, crashes: [Date(), Date()])
        XCTAssertLessThanOrEqual(HealthReport.checks(for: worst).count, HealthLimits.checks)
        XCTAssertLessThanOrEqual(HealthReport.readings(for: worst).count, HealthLimits.readings)
    }

    // MARK: Crash reports

    func testOnlyThisProcesssCrashReportsAreCounted() {
        XCTAssertTrue(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010.ips", process: "SherlockMe"))
        XCTAssertTrue(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010.crash", process: "SherlockMe"))
        XCTAssertTrue(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010-1.ips", process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "ExcUserFault_SherlockMe-2026-09-21-101010.ips",
                                                  process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "SherlockMeHelper-2026-09-21-101010.ips",
                                                  process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "SherlockMe-notes.ips", process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010.diag", process: "SherlockMe"))
    }

    // MARK: The words

    func testDurationsReadInTheTwoLargestUnits() {
        let t = Loc.settings.health
        XCTAssertEqual(t.duration(seconds: 30), "Less than a minute")
        XCTAssertEqual(t.duration(seconds: 125), "2 min")
        XCTAssertEqual(t.duration(seconds: 3_720), "1 h 2 min")
        XCTAssertEqual(t.duration(seconds: 2 * 86_400 + 3 * 3_600 + 59), "2 d 3 h")
        Loc.language = .fr
        XCTAssertEqual(Loc.settings.health.duration(seconds: 2 * 86_400 + 3 * 3_600), "2 j 3 h")
    }

    func testHowLongAgo() {
        let t = Loc.settings.health
        XCTAssertEqual(t.ago(seconds: 30), "Just now")
        XCTAssertEqual(t.ago(seconds: 125), "2 min ago")
        XCTAssertEqual(t.ago(seconds: 2 * 86_400 + 3 * 3_600), "2 d 3 h ago")
        Loc.language = .fr
        XCTAssertEqual(Loc.settings.health.ago(seconds: 30), "À l'instant")
        XCTAssertEqual(Loc.settings.health.ago(seconds: 125), "Il y a 2 min")
    }
}
