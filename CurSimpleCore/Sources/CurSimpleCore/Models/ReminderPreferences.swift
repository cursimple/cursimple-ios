import Foundation

/// Class reminder preferences; the planner turns these into dated notifications.
public struct ReminderPreferences: Codable, Hashable, Sendable {

    public var enabled: Bool
    /// Minutes before the class starts; 0 means at class time.
    public var advanceMinutes: Int
    public var includeExams: Bool
    /// Rolling window of days scheduled ahead. iOS keeps at most 64 pending
    /// local notifications, so the window is intentionally short and refreshed.
    public var horizonDays: Int

    public init(
        enabled: Bool = false,
        advanceMinutes: Int = 45,
        includeExams: Bool = true,
        horizonDays: Int = 7
    ) {
        self.enabled = enabled
        self.advanceMinutes = advanceMinutes
        self.includeExams = includeExams
        self.horizonDays = horizonDays
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, advanceMinutes, includeExams, horizonDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        advanceMinutes = min(max(
            try container.decodeIfPresent(Int.self, forKey: .advanceMinutes) ?? 45,
            0
        ), 720)
        includeExams = try container.decodeIfPresent(Bool.self, forKey: .includeExams) ?? true
        horizonDays = min(max(
            try container.decodeIfPresent(Int.self, forKey: .horizonDays) ?? 7,
            1
        ), 14)
    }

    public static let advanceOptions = [0, 5, 10, 15, 20, 30, 45, 60]

    public var normalized: ReminderPreferences {
        var copy = self
        copy.advanceMinutes = min(max(advanceMinutes, 0), 720)
        copy.horizonDays = min(max(horizonDays, 1), 14)
        return copy
    }
}

/// A dated reminder ready for the notification center.
public struct PlannedReminder: Identifiable, Hashable, Sendable {

    public let course: CourseItem
    public let start: Date
    public let fireAt: Date
    public let sourceWeek: Int?

    public init(course: CourseItem, start: Date, fireAt: Date, sourceWeek: Int?) {
        self.course = course
        self.start = start
        self.fireAt = fireAt
        self.sourceWeek = sourceWeek
    }

    /// Stable identity so rescheduling replaces the same request instead of duplicating it.
    public var id: String {
        "\(course.id)-\(Int(start.timeIntervalSince1970))"
    }

    public var title: String { course.title(forWeek: sourceWeek) }
    public var location: String { course.location(forWeek: sourceWeek) }
    public var teacher: String { course.teacher(forWeek: sourceWeek) }
}

/// Pending-notification budget; leave headroom below the system limit of 64.
public let maxPlannedReminders = 60

/**
 Occurences inside the rolling window, each fired `advanceMinutes` before class.

 Courses outside the term's teaching weeks, hidden courses and untimed courses are
 skipped. Results are sorted by fire time and capped.
 */
public func plannedReminders(
    term: Term,
    profile: TimingProfile?,
    preferences: ReminderPreferences,
    now: Date,
    calendar: Calendar = .current
) -> [PlannedReminder] {
    let preferences = preferences.normalized
    guard preferences.enabled, let termStart = term.startDateValue else { return [] }

    let advance = TimeInterval(preferences.advanceMinutes * 60)
    var reminders: [PlannedReminder] = []
    var seen = Set<String>()

    for offset in 0...preferences.horizonDays {
        let date = ScheduleCalendar.addDays(offset, to: now, calendar: calendar)
        let week = ScheduleCalendar.teachingWeekNumber(
            termStart: termStart,
            date: date,
            calendar: calendar
        )
        guard week >= 1, week <= term.weekCount else { continue }

        for item in occurrences(
            on: date,
            courses: term.courses,
            week: week,
            profile: profile,
            calendar: calendar
        ) {
            guard let start = item.start, item.hasTime else { continue }
            if !preferences.includeExams && item.course.category == .exam { continue }

            let fireAt = start.addingTimeInterval(-advance)
            guard fireAt > now else { continue }

            let reminder = PlannedReminder(
                course: item.course,
                start: start,
                fireAt: fireAt,
                sourceWeek: item.sourceWeek
            )
            guard seen.insert(reminder.id).inserted else { continue }
            reminders.append(reminder)
        }
    }

    return Array(reminders.sorted { $0.fireAt < $1.fireAt }.prefix(maxPlannedReminders))
}
