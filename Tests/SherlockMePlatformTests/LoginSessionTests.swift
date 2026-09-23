import XCTest
import SherlockMePlatform

final class LoginSessionTests: XCTestCase {
    /// The directory service agrees with `id -Gn`, which lists `admin` for an administrator.
    func testTheAdministratorAnswerAgreesWithId() throws {
        let id = Process()
        id.executableURL = URL(fileURLWithPath: "/usr/bin/id")
        id.arguments = ["-Gn"]
        let pipe = Pipe()
        id.standardOutput = pipe
        try id.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        id.waitUntilExit()
        let groups = output.split(whereSeparator: \.isWhitespace).map(String.init)
        XCTAssertEqual(LoginSession.userIsAdministrator, groups.contains("admin"))
    }

    /// The window server agrees with `who`, which lists the user at the keyboard on the `console` line.
    func testTheConsoleAnswerAgreesWithWho() throws {
        let who = Process()
        who.executableURL = URL(fileURLWithPath: "/usr/bin/who")
        let pipe = Pipe()
        who.standardOutput = pipe
        try who.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        who.waitUntilExit()
        let atTheKeyboard = output.split(separator: "\n").contains { line in
            let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
            return words.count >= 2 && words[0] == NSUserName() && words[1] == "console"
        }
        XCTAssertEqual(LoginSession.isOnConsole, atTheKeyboard)
    }
}
