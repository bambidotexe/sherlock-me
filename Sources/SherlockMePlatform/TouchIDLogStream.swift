import Foundation
import SherlockMeCore

/// `log stream`, reading the Touch ID lines as they are written: one child process for as long as it runs.
/// Its lines are parsed by `TouchIDLog` and handed over on the queue the stream was given, in the order they
/// came, and its end is reported there once, after its last line. `stop()` is not an end.
///
/// Every method is called on that queue.
public final class TouchIDLogStream: @unchecked Sendable {
    private let queue: DispatchQueue
    private let executable: URL
    private let arguments: [String]
    private let uid: UInt32
    private let onEvent: (Date, TouchIDEvent) -> Void
    private let onEnd: (Int32) -> Void

    private var process: Process?
    private var buffer = Data()
    private var pipeClosed = false
    private var exitStatus: Int32?
    private var finished = false

    /// The real stream is `/usr/bin/log stream --style ndjson` with `TouchIDLog.predicate`; a test passes a
    /// stand-in that prints lines of its own. `uid` is the session whose lock and unlock are this app's: the
    /// user it runs as, and another one's session in front is not read as this one.
    public init(queue: DispatchQueue,
                executable: URL = URL(fileURLWithPath: "/usr/bin/log"),
                arguments: [String] = ["stream", "--style", "ndjson", "--predicate", TouchIDLog.predicate],
                uid: UInt32 = getuid(),
                onEvent: @escaping (Date, TouchIDEvent) -> Void,
                onEnd: @escaping (Int32) -> Void) {
        self.queue = queue
        self.executable = executable
        self.arguments = arguments
        self.uid = uid
        self.onEvent = onEvent
        self.onEnd = onEnd
    }

    /// Starts the child. Throws when it cannot be started at all.
    public func start() throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            // An empty read is the end of the pipe; the handler would be called for it again and again.
            if chunk.isEmpty { handle.readabilityHandler = nil }
            self?.queue.async { chunk.isEmpty ? self?.pipeDidClose() : self?.consume(chunk) }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            self?.queue.async { self?.childDidExit(status) }
        }
        try process.run()
        self.process = process
    }

    /// Ends the child, and reports nothing more: no line, no end.
    public func stop() {
        finished = true
        (process?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
    }

    private func consume(_ chunk: Data) {
        guard !finished else { return }
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let (time, event) = TouchIDLog.parse(Data(line), uid: uid) { onEvent(time, event) }
        }
    }

    private func pipeDidClose() {
        pipeClosed = true
        reportTheEndOnce()
    }

    private func childDidExit(_ status: Int32) {
        exitStatus = status
        reportTheEndOnce()
    }

    /// Only once both the child has exited and its last line has been read, so no line comes after the end.
    private func reportTheEndOnce() {
        guard !finished, pipeClosed, let status = exitStatus else { return }
        finished = true
        process = nil
        onEnd(status)
    }
}
