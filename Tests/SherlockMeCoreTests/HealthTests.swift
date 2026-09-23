import XCTest
@testable import SherlockMeCore

/// The Health page's rules: which colour a check takes, which lines every app adds while they are wrong,
/// how long the two tables may grow, and which files are this app's crash reports.
final class HealthTests: XCTestCase {
    override func tearDown() {
        Loc.language = .en
        super.tearDown()
    }

    private func facts(crashes: [Date] = []) -> HealthFacts {
        HealthFacts(runningSeconds: 3_720, memoryBytes: 48 * 1_048_576, recentCrashes: crashes)
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

    // MARK: The tables

    func testAHealthyAppHasNothingWrongToShow() {
        XCTAssertEqual(HealthReport.checks(for: facts()), [])
    }

    func testTheReadings() {
        XCTAssertEqual(HealthReport.readings(for: facts()).map(\.value), ["1 h 2 min", "48 MB"])
    }

    func testACrashIsALineOnlyWhileThereIsOne() {
        let crash = Date(timeIntervalSince1970: 1_790_000_000)
        let checks = HealthReport.checks(for: facts(crashes: [crash]))
        XCTAssertEqual(checks.map(\.id), ["crashes"])
        XCTAssertEqual(checks.first?.level, .warning)
        XCTAssertEqual(checks.first?.word, "1")
        XCTAssertEqual(checks.first?.detail, "Last one \(HealthReport.stamp(crash))")
        XCTAssertEqual(checks.warnings, [Loc.settings.health.crashesFix])
    }

    func testTheTablesStayShortInTheWorstCase() {
        let worst = facts(crashes: [Date(), Date()])
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
}
