import Foundation

/// A user-created alarm: a specific time on chosen weekdays, independent of the
/// timetable. Class alarms come from reminders; these are the manual ones.
public struct Alarm: Codable, Identifiable, Hashable, Sendable {

    public var id: String
    public var hour: Int
    public var minute: Int
    /// ISO weekdays 1...7; empty means every day.
    public var weekdays: [Int]
    public var label: String
    public var enabled: Bool
    /// Snooze length in minutes offered when the alarm fires.
    public var snoozeMinutes: Int
    public var createdAtMillis: Int64

    public init(
        id: String = UUID().uuidString,
        hour: Int = 7,
        minute: Int = 0,
        weekdays: [Int] = [],
        label: String = "",
        enabled: Bool = true,
        snoozeMinutes: Int = 5,
        createdAtMillis: Int64 = 0
    ) {
        self.id = id
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.weekdays = Self.normalizedWeekdays(weekdays)
        self.label = label
        self.enabled = enabled
        self.snoozeMinutes = min(max(snoozeMinutes, 1), 60)
        self.createdAtMillis = createdAtMillis
    }

    private enum CodingKeys: String, CodingKey {
        case id, hour, minute, weekdays, label, enabled, snoozeMinutes, createdAtMillis
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        hour = min(max(try container.decodeIfPresent(Int.self, forKey: .hour) ?? 7, 0), 23)
        minute = min(max(try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0, 0), 59)
        weekdays = Self.normalizedWeekdays(
            try container.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        )
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        snoozeMinutes = min(max(try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5, 1), 60)
        createdAtMillis = try container.decodeIfPresent(Int64.self, forKey: .createdAtMillis) ?? 0
    }

    private static func normalizedWeekdays(_ days: [Int]) -> [Int] {
        Array(Set(days.filter { (1...7).contains($0) })).sorted()
    }

    public var time: TimeOfDay {
        TimeOfDay(hour: hour, minute: minute)
    }

    public var displayLabel: String {
        label.isEmpty ? String(localized: "alarm.defaultLabel") : label
    }

    /// Every day when no weekday is selected.
    public func fires(onWeekday weekday: Int) -> Bool {
        weekdays.isEmpty || weekdays.contains(weekday)
    }
}

/// The next `count` firing dates from `now`, capped by a horizon in days.
public func nextAlarmFires(
    _ alarm: Alarm,
    after now: Date,
    count: Int = 8,
    horizonDays: Int = 14,
    calendar: Calendar = .current
) -> [Date] {
    guard alarm.enabled, count > 0 else { return [] }
    var result: [Date] = []
    var day = calendar.startOfDay(for: now)

    for _ in 0...max(horizonDays, 1) {
        let weekday = ScheduleCalendar.isoDayOfWeek(day, calendar: calendar)
        if alarm.fires(onWeekday: weekday),
           let fire = alarm.time.date(on: day, calendar: calendar),
           fire > now {
            result.append(fire)
            if result.count >= count { return result }
        }
        day = ScheduleCalendar.addDays(1, to: day, calendar: calendar)
    }
    return result
}

/// Alarms sorted by their next firing time; disabled ones keep creation order.
public func sortedAlarms(_ alarms: [Alarm], now: Date = .now, calendar: Calendar = .current) -> [Alarm] {
    alarms.sorted { lhs, rhs in
        if lhs.enabled != rhs.enabled { return lhs.enabled }
        let lhsNext = nextAlarmFires(lhs, after: now, count: 1, calendar: calendar).first ?? .distantFuture
        let rhsNext = nextAlarmFires(rhs, after: now, count: 1, calendar: calendar).first ?? .distantFuture
        if lhsNext != rhsNext { return lhsNext < rhsNext }
        return lhs.createdAtMillis < rhs.createdAtMillis
    }
}

/// Human summary of the repeat days: every day, weekdays only, or a list.
public enum AlarmRepeatSummary: Equatable, Sendable {
    case everyDay
    case weekdays
    case weekend
    case specific([Int])
}

public func alarmRepeatSummary(_ alarm: Alarm) -> AlarmRepeatSummary {
    let days = alarm.weekdays
    if days.isEmpty || days.count == 7 { return .everyDay }
    if days == [1, 2, 3, 4, 5] { return .weekdays }
    if days == [6, 7] { return .weekend }
    return .specific(days)
}
