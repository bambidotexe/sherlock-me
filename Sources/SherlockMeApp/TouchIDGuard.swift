import Foundation
import SherlockMeCore
import SherlockMePlatform

/// SherlockMe's one behaviour. It reads the Touch ID lines off the log (`TouchIDLogStream`), runs them
/// through `LockRule`, and locks when the rule says so. Every decision is the rule's; this carries the lines
/// in and the actions out, and starts the stream again when it ends.
///
/// **Everything it does runs on one serial queue of its own**, never the main thread, so a window being drawn
/// never delays a lock. The menu and the Health page read `status`, a copy kept under a lock.
///
/// **It holds nothing in macOS** (`docs/functional.md` §0): no hold on loginwindow, no preference, no setting.
/// Whenever it is not running or cannot read the log, the Touch ID key does exactly what macOS makes it do.
final class TouchIDGuard: @unchecked Sendable {
    static let shared = TouchIDGuard()

    struct Status: Equatable {
        var watcher: WatcherState = .stopped
        /// When the Touch ID key last locked the Mac, and when the rule last locked it again.
        var lastLock: Date?
        var lastRelock: Date?
    }

    private let queue = DispatchQueue(label: "\(AppIdentity.bundleIdentifier).touchid", qos: .userInteractive)
    private let statusLock = NSLock()
    private var current = Status()

    // Read and written on `queue` only.
    private var running = false
    private var rule = LockRule(screenIsLocked: false)
    private var stream: TouchIDLogStream?
    private var streamStarted: Date?
    private var failures = 0

    /// What the menu and the Health page show. Any thread.
    var status: Status { statusLock.withLock { current } }

    /// Starts watching, at launch. Nothing here asks for a permission: an administrator account reads the log
    /// without one, and on any other account nothing is started.
    func start() {
        queue.async { [self] in
            guard !running else { return }
            running = true
            guard LoginSession.userIsAdministrator else {
                update { $0.watcher = .needsAdministrator }
                Log.touchID.notice("not watching: this account is not an administrator, and only one can read the log")
                return
            }
            let canLock = SessionAgent.canLock
            Log.touchID.notice("the lock call is \(canLock ? "there" : "missing", privacy: .public)")
            startStream()
        }
    }

    /// Stops the stream before the process goes: a quit, an update's install and the uninstall all leave
    /// through `NSApp.terminate`. Synchronous: when this returns, the `log` child has been sent its end
    /// (`terminate()`, nothing waits for it to exit), and no line or end of it reaches the rule.
    func stop() {
        queue.sync { [self] in
            running = false
            stream?.stop()
            stream = nil
            update { $0.watcher = .stopped }
        }
    }

    // MARK: - The stream

    private func startStream() {
        guard running else { return }
        // A fresh rule each time: a press that was under way when a stream ended is forgotten, which can
        // only cost a relock, never make one in error.
        rule = LockRule(screenIsLocked: LoginSession.screenIsLocked)
        let stream = TouchIDLogStream(queue: queue,
                                      onEvent: { [weak self] time, event in self?.handle(event, at: time) },
                                      onEnd: { [weak self] status in self?.streamEnded(status: status) })
        do {
            try stream.start()
        } catch {
            Log.touchID.error("log stream could not start: \(error.localizedDescription, privacy: .public)")
            startAgainLater(ranFor: 0)
            return
        }
        self.stream = stream
        streamStarted = Date()
        update { $0.watcher = .watching }
        Log.touchID.notice("watching the Touch ID key, the screen \(self.rule.screenIsLocked ? "locked" : "unlocked", privacy: .public)")
    }

    private func streamEnded(status: Int32) {
        stream = nil
        let ranFor = streamStarted.map { Date().timeIntervalSince($0) } ?? 0
        Log.touchID.error("log stream ended, status \(status), after \(Int(ranFor)) s")
        startAgainLater(ranFor: ranFor)
    }

    private func startAgainLater(ranFor: TimeInterval) {
        update { $0.watcher = .stopped }
        failures = WatchRestart.failures(previous: failures, ranFor: ranFor)
        let delay = WatchRestart.delay(afterFailures: failures)
        Log.touchID.notice("starting log stream again in \(Int(delay)) s, end \(self.failures) in a row")
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in self?.startStream() }
    }

    // MARK: - The rule

    private func handle(_ event: TouchIDEvent, at time: Date) {
        Log.touchID.debug("\(String(describing: event), privacy: .public) at \(time.timeIntervalSince1970, privacy: .public)")
        // The log can miss a lock: one that lands while a stream is starting is never read. A press on a Mac
        // the window server says is locked is then a press on the lock screen, unless SherlockMe locked it
        // itself within `K.sameKeyPress`, where the log's own line may simply not have come yet.
        if event == .keyDown, !rule.screenIsLocked, LoginSession.screenIsLocked,
           status.lastLock.map({ Date().timeIntervalSince($0) >= K.sameKeyPress }) ?? true {
            Log.touchID.notice("a press on a Mac the log did not say was locked: taking it as locked")
            perform(rule.handle(.screenLocked, at: time))
        }
        perform(rule.handle(event, at: time))
    }

    private func perform(_ actions: [LockRule.Action]) {
        for action in actions {
            switch action {
            case .lock:
                let result = SessionAgent.lockScreen()
                update { $0.lastLock = Date() }
                if result == 0 {
                    Log.touchID.notice("the Touch ID key went down: locked")
                } else {
                    Log.touchID.error("the Touch ID key went down: the lock failed, result \(result)")
                }
            case .relock:
                let result = SessionAgent.lockScreen()
                update { $0.lastRelock = Date() }
                if result == 0 {
                    Log.touchID.notice("the finger that pressed the key unlocked the Mac: locked again")
                } else {
                    Log.touchID.error("the finger that pressed the key unlocked the Mac: the relock failed, result \(result)")
                }
            case .wake(let due):
                queue.asyncAfter(deadline: .now() + max(0, due.timeIntervalSinceNow)) { [weak self] in
                    guard let self, self.running else { return }
                    // Never earlier than the rule asked, even if the wall clock stepped meanwhile.
                    self.perform(self.rule.tick(at: max(Date(), due)))
                }
            case .followedMacOSLock:
                update { $0.lastLock = Date() }
                Log.touchID.notice("macOS locked on a press whose key line was not read: following that press")
            case .leftUnlocked(let reason):
                Log.touchID.notice("unlock left alone: \(String(describing: reason), privacy: .public)")
            }
        }
    }

    private func update(_ change: (inout Status) -> Void) {
        statusLock.withLock { change(&current) }
    }
}
