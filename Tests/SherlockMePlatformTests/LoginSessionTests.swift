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
}
