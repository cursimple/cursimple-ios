import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Reminder planner")
struct ReminderPlannerTests {

    let calendar = makeTestCalendar()

    private func moment(_ day: String, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        let parts = day.split(separator: "-").compactMap { Int($0) }
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    private var profile: TimingProfile { .defaultProfile() }

    @Test("Disabled reminders plan nothing")
    func disabled() {
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: false),
            now: moment("2026-09-07", hour: 6),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test("Fires the lead time before class")
    func leadTime() {
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let now = moment("2026-09-07", hour: 6)
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 45, horizonDays: 3),
            now: now,
            calendar: calendar
        )

        #expect(result.count == 1)
        #expect(result[0].fireAt == moment("2026-09-07", hour: 7, minute: 15))
        #expect(result[0].start == moment("2026-09-07", hour: 8))
        #expect(result[0].id.contains("a"))
    }

    @Test("Zero lead time fires at the start")
    func atStart() {
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 0, horizonDays: 3),
            now: moment("2026-09-07", hour: 6),
            calendar: calendar
        )
        #expect(result.first?.fireAt == moment("2026-09-07", hour: 8))
    }

    @Test("Past fire times are skipped")
    func pastSkipped() {
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 45, horizonDays: 3),
            now: moment("2026-09-07", hour: 8),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test("Hidden courses and hidden weeks are skipped")
    func filtering() {
        var hidden = makeCourse(id: "hidden", day: 1, start: 1, end: 2)
        hidden.hidden = true
        let oddWeek = makeCourse(id: "odd", day: 1, start: 3, end: 4, weeks: [2])

        let term = makeTerm(courses: [hidden, oddWeek])
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 15, horizonDays: 7),
            now: moment("2026-09-07", hour: 6), // week 1
            calendar: calendar
        )
        #expect(result.map(\.course.id) == ["odd"])
    }

    @Test("Exam reminders follow the includeExams switch")
    func examSwitch() {
        let exam = makeCourse(id: "exam", day: 1, start: 1, end: 2, category: .exam)
        let term = makeTerm(courses: [exam])

        let included = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, includeExams: true, horizonDays: 3),
            now: moment("2026-09-07", hour: 6),
            calendar: calendar
        )
        #expect(included.count == 1)

        let excluded = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, includeExams: false, horizonDays: 3),
            now: moment("2026-09-07", hour: 6),
            calendar: calendar
        )
        #expect(excluded.isEmpty)
    }

    @Test("Typed clock times drive the reminder")
    func typedClock() {
        var course = makeCourse(id: "a", day: 1, start: 1, end: 2)
        course.reminderStartTime = "18:30"
        course.reminderEndTime = "20:00"

        let term = makeTerm(courses: [course])
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 30, horizonDays: 3),
            now: moment("2026-09-07", hour: 12),
            calendar: calendar
        )
        #expect(result.first?.fireAt == moment("2026-09-07", hour: 18))
    }

    @Test("Reminders sort by fire time across days")
    func sorting() {
        let early = makeCourse(id: "early", day: 1, start: 1, end: 1)
        let later = makeCourse(id: "later", day: 2, start: 5, end: 5)
        let term = makeTerm(courses: [later, early])

        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 10, horizonDays: 3),
            now: moment("2026-09-07", hour: 6),
            calendar: calendar
        )
        #expect(result.map(\.course.id) == ["early", "later"])
    }

    @Test("Output stays inside the pending-notification budget")
    func cap() {
        var courses: [CourseItem] = []
        for day in 1...7 {
            for node in 1...11 {
                courses.append(makeCourse(id: "c-\(day)-\(node)", day: day, start: node, end: node))
            }
        }
        let term = makeTerm(courses: courses)
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 0, horizonDays: 7),
            now: moment("2026-09-07", hour: 0),
            calendar: calendar
        )
        #expect(result.count == maxPlannedReminders)
        #expect(result.count < 64)
    }

    @Test("Duplicate occurrences produce one reminder")
    func dedupe() {
        let course = makeCourse(id: "a", day: 1, start: 1, end: 2)
        let term = makeTerm(courses: [course, course])
        let result = plannedReminders(
            term: term,
            profile: profile,
            preferences: ReminderPreferences(enabled: true, advanceMinutes: 10, horizonDays: 3),
            now: moment("2026-09-07", hour: 6),
            calendar: calendar
        )
        #expect(result.count == 1)
    }
}
