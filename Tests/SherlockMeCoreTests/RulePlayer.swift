import Foundation
import SherlockMeCore

/// Plays lines through a `LockRule` in the order and with the times they were logged, waking it when it asked
/// to be woken, the way the app does. What the rule decides changes nothing that follows: a recording
/// already holds whatever locked the Mac at the time.
enum RulePlayer {
    struct Step: Equatable {
        let time: Date
        let action: LockRule.Action
    }

    static func play(_ lines: [(time: Date, event: TouchIDEvent)], screenIsLocked: Bool = false) -> [Step] {
        var rule = LockRule(screenIsLocked: screenIsLocked)
        var wakes: [Date] = []
        var steps: [Step] = []
        func record(_ actions: [LockRule.Action], at time: Date) {
            for action in actions {
                steps.append(Step(time: time, action: action))
                if case .wake(let due) = action { wakes.append(due) }
            }
        }
        for line in lines {
            while let due = wakes.min(), due <= line.time {
                wakes.removeAll { $0 == due }
                record(rule.tick(at: due), at: due)
            }
            record(rule.handle(line.event, at: line.time), at: line.time)
        }
        for due in wakes.sorted() { record(rule.tick(at: due), at: due) }
        return steps
    }
}
