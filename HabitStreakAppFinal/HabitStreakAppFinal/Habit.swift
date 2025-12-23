import Foundation
import SwiftData

enum HabitGoalType: String, Codable, Sendable {
    case count
    case date
}

@Model
final class Habit {
    var title: String
    var createdAt: Date
    var dueDate: Date?
    var lastCompletedAt: Date?
    var streak: Int
    var checkIns: [Date]
    var goalType: HabitGoalType
    var targetCount: Int?

    init(title: String) {
        self.title = title
        self.createdAt = .now
        self.streak = 0
        self.checkIns = []
        self.goalType = .date
        self.targetCount = nil
    }
}

extension Habit {
    var displayStreak: String { "\(streak)🔥" }

    var completionCount: Int { checkIns.count }

    /// Record a completion regardless of day; increments count and keeps timestamp log.
    func recordCompletion() {
        checkIns.append(.now)
        lastCompletedAt = .now
    }

    func completeToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if let last = lastCompletedAt {
            let lastDay = cal.startOfDay(for: last)
            if lastDay == today { return }
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            streak = (lastDay == yesterday) ? streak + 1 : 1
        } else {
            streak = 1
        }

        lastCompletedAt = .now
    }
}
