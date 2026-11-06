import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Holiday resolution")
struct HolidayTests {

    let calendar = makeTestCalendar()
    var none: HolidayCalendarSettings { HolidayCalendarSettings(builtInEnabled: false) }

    @Test("Bundled 2026 declarations resolve by date")
    func builtIn() {
        let nationalDay = testDay("2026-10-01")
        let entry = BuiltInHolidayCalendar.entry(on: nationalDay, calendar: calendar)
        #expect(entry?.kind == .holiday)
        #expect(entry?.name == "国庆节")

        let ordinary = testDay("2026-10-12")
        #expect(BuiltInHolidayCalendar.entry(on: ordinary, calendar: calendar) == nil)

        // 2026-02-16 is除夕 per the shared dataset.
        let eve = BuiltInHolidayCalendar.entry(on: testDay("2026-02-16"), calendar: calendar)
        #expect(eve?.name == "除夕")
    }

    @Test("User entries override bundled declarations for the same day")
    func userOverrides() {
        var settings = HolidayCalendarSettings()
        settings = settings.upsertingUser(HolidayCalendarEntry(date: "2026-10-01", kind: .workday, name: "手动调课"))
        let resolution = resolveScheduleDay(
            date: testDay("2026-10-01"),
            overrides: [],
            holidayCalendar: settings,
            calendar: calendar
        )
        #expect(!resolution.isHoliday)
    }

    @Test("Synced year replaces the bundled snapshot for that year only")
    func syncedReplacesBundled() {
        var settings = HolidayCalendarSettings()
        settings = settings.replacingSyncedYear(SyncedHolidayYear(year: 2026, entries: [
            HolidayCalendarEntry(date: "2026-10-01", kind: .holiday, name: "官方国庆"),
        ]))

        // The synced year hides the bundled 10-07 entry.
        let lastDay = resolveScheduleDay(
            date: testDay("2026-10-07"),
            overrides: [],
            holidayCalendar: settings,
            calendar: calendar
        )
        #expect(!lastDay.isHoliday)

        // Other years still use bundled data.
        let other = BuiltInHolidayCalendar.entry(on: testDay("2026-06-19"), calendar: calendar)
        #expect(other?.name == "端午节")
    }

    @Test("Holidays suppress occurrences")
    func holidaySuppresses() {
        let course = makeCourse(id: "a", day: 4, start: 1, end: 2) // Thursday
        let term = makeTerm(courses: [course])
        var settings = HolidayCalendarSettings()
        settings = settings.upsertingUser(HolidayCalendarEntry(date: "2026-09-10", kind: .holiday, name: "校庆"))

        let items = scheduledCourseOccurrencesOn(
            date: testDay("2026-09-10"),
            courses: term.courses,
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: term.startDateValue,
            overrides: [],
            holidayCalendar: settings,
            calendar: calendar
        )
        #expect(items.isEmpty)
    }

    @Test("Make-up workdays carry the source day's courses")
    func makeUpWorkday() {
        // Sunday 2026-09-27 is中秋节 (holiday); a workday override turns it into Thursday's timetable.
        let settings = HolidayCalendarSettings() // bundled data active
        let sunday = testDay("2026-09-27")
        let thursday = testDay("2026-09-24")

        var settings2 = settings
        settings2 = settings2.upsertingUser(HolidayCalendarEntry(date: "2026-09-27", kind: .workday, name: "调休"))
        let override = TemporaryScheduleOverride(
            type: .makeUp,
            targetDate: "2026-09-27",
            sourceDate: "2026-09-24"
        )

        let items = scheduledCourseOccurrencesOn(
            date: sunday,
            courses: [makeCourse(id: "thu", day: 4, start: 1, end: 2)],
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: testDay("2026-09-01"),
            overrides: [override],
            holidayCalendar: settings2,
            calendar: calendar
        )
        #expect(items.count == 1)
        #expect(items[0].course.id == "thu")

        _ = thursday
    }

    @Test("Bundled holiday blocks the day unless a make-up override applies")
    func overrideBeatsHoliday() {
        let settings = HolidayCalendarSettings()
        // 2026-10-01 is a bundled holiday (Thursday).
        let holiday = resolveScheduleDay(
            date: testDay("2026-10-01"),
            overrides: [],
            holidayCalendar: settings,
            calendar: calendar
        )
        #expect(holiday.isHoliday)

        let override = TemporaryScheduleOverride(
            type: .makeUp,
            targetDate: "2026-10-01",
            sourceDate: "2026-09-30"
        )
        let overridden = resolveScheduleDay(
            date: testDay("2026-10-01"),
            overrides: [override],
            holidayCalendar: settings,
            calendar: calendar
        )
        #expect(!overridden.isHoliday)
        #expect(overridden.sourceDate == testDay("2026-09-30"))
    }
}

@Suite("Schedule overrides")
struct OverrideTests {

    let calendar = makeTestCalendar()

    @Test("Whole-day make-up pulls every course from the source day")
    func wholeDaySwap() {
        let monday = makeCourse(id: "mon", day: 1, start: 1, end: 2)
        let term = makeTerm(courses: [monday])
        let override = TemporaryScheduleOverride(
            type: .makeUp,
            targetDate: "2026-09-08", // Tuesday
            sourceDate: "2026-09-07" // Monday
        )

        let items = scheduledCourseOccurrencesOn(
            date: testDay("2026-09-08"),
            courses: term.courses,
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: testDay("2026-09-01"),
            overrides: [override],
            holidayCalendar: HolidayCalendarSettings(builtInEnabled: false),
            calendar: calendar
        )
        #expect(items.count == 1)
        #expect(items[0].course.id == "mon")
        #expect(items[0].sourceWeek == 2)
    }

    @Test("Partial make-up keeps out-of-range courses on their own day")
    func partialSwap() {
        let mondayFirst = makeCourse(id: "p1", day: 1, start: 1, end: 2)
        let mondayLate = makeCourse(id: "p5", day: 1, start: 5, end: 6)
        let term = makeTerm(courses: [mondayFirst, mondayLate])
        let override = TemporaryScheduleOverride(
            type: .makeUp,
            targetDate: "2026-09-08",
            sourceDate: "2026-09-07",
            makeUpStartNode: 1,
            makeUpEndNode: 2
        )

        let items = scheduledCourseOccurrencesOn(
            date: testDay("2026-09-08"),
            courses: term.courses,
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: testDay("2026-09-01"),
            overrides: [override],
            holidayCalendar: HolidayCalendarSettings(builtInEnabled: false),
            calendar: calendar
        )
        #expect(items.map(\.course.id) == ["p1"])
    }

    @Test("Cancel removes one course and keeps the rest")
    func cancelCourse() {
        let kept = makeCourse(id: "keep", day: 1, start: 1, end: 2)
        let dropped = makeCourse(id: "drop", day: 1, start: 3, end: 4)
        let term = makeTerm(courses: [kept, dropped])
        let override = TemporaryScheduleOverride(
            type: .cancelCourse,
            targetDate: "2026-09-07",
            cancelStartNode: 3,
            cancelEndNode: 4,
            cancelCourseId: "drop"
        )

        let items = scheduledCourseOccurrencesOn(
            date: testDay("2026-09-07"),
            courses: term.courses,
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: testDay("2026-09-01"),
            overrides: [override],
            holidayCalendar: HolidayCalendarSettings(builtInEnabled: false),
            calendar: calendar
        )
        #expect(items.map(\.course.id) == ["keep"])
    }

    @Test("Move relocates one course to the target day and periods")
    func moveCourse() {
        let course = makeCourse(id: "m", day: 1, start: 1, end: 2)
        let term = makeTerm(courses: [course])
        let override = TemporaryScheduleOverride(
            type: .moveCourse,
            targetDate: "2026-09-09", // Wednesday
            sourceDate: "2026-09-07",
            moveCourseId: "m",
            moveToStartNode: 5,
            moveToEndNode: 6
        )

        let monday = scheduledCourseOccurrencesOn(
            date: testDay("2026-09-07"),
            courses: term.courses,
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: testDay("2026-09-01"),
            overrides: [override],
            holidayCalendar: HolidayCalendarSettings(builtInEnabled: false),
            calendar: calendar
        )
        #expect(monday.isEmpty, "moved course must leave its original day")

        let termTyped = term
        let wednesday = scheduledCourseOccurrencesOn(
            date: testDay("2026-09-09"),
            courses: termTyped.courses,
            timingProfile: TimingProfile.defaultProfile(),
            termStartDate: testDay("2026-09-01"),
            overrides: [override],
            holidayCalendar: HolidayCalendarSettings(builtInEnabled: false),
            calendar: calendar
        )
        #expect(wednesday.count == 1)
        #expect(wednesday[0].course.time.startNode == 5)
        #expect(wednesday[0].course.time.dayOfWeek == 3)
        #expect(wednesday[0].sourceWeek == 2) // source week label
    }

    @Test("Returning a moved course to its natural slot removes the override")
    func moveBackToNatural() {
        let plan = planCourseMove(
            overrides: [],
            courseId: "m",
            from: testDay("2026-09-07"),
            to: testDay("2026-09-09"),
            toStartNode: 5,
            toEndNode: 6,
            naturalStartNode: 1,
            naturalEndNode: 2,
            newId: { "new" }
        )
        #expect(plan.upsert != nil)

        let planBack = planCourseMove(
            overrides: [plan.upsert!],
            courseId: "m",
            from: testDay("2026-09-09"),
            to: testDay("2026-09-07"),
            toStartNode: 1,
            toEndNode: 2,
            naturalStartNode: 1,
            naturalEndNode: 2,
            newId: { "new2" }
        )
        #expect(planBack.upsert == nil)
        #expect(planBack.removeIds == [plan.upsert!.id])
    }
}

@Suite("Holiday dataset parsing")
struct HolidayDatasetTests {

    @Test("Valid dataset parses with kinds and dedupes")
    func valid() {
        let body = """
        {"year":2027,"days":[
          {"name":"元旦","date":"2027-01-01","isOffDay":true},
          {"name":"元旦","date":"2027-01-01","isOffDay":true},
          {"name":"调休上班","date":"2027-01-09","isOffDay":false}
        ]}
        """
        let result = HolidayDatasetParser.parse(body, expectedYear: 2027)
        guard case .success(let year, let entries) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(year == 2027)
        #expect(entries.count == 2)
        #expect(entries[0].kind == .holiday)
        #expect(entries[1].kind == .workday)
    }

    @Test("Malformed JSON and wrong years are rejected")
    func rejection() {
        #expect(HolidayDatasetParser.parse("not json", expectedYear: 2027) == .malformed)
        #expect(HolidayDatasetParser.parse(
            #"{"year":2026,"days":[]}"#,
            expectedYear: 2027
        ) == .yearMismatch(expected: 2027, actual: 2026))
        #expect(HolidayDatasetParser.parse(
            #"{"year":2027,"days":[{"name":"x","date":"2027-02-30"}]}"#,
            expectedYear: 2027
        ) == .empty)
    }

    @Test("Bundled entries cover 2026")
    func bundledCoverage() {
        #expect(BuiltInHolidayCalendar.coveredYears == [2026])
        #expect(BuiltInHolidayCalendar.entries(ofYear: 2026).count == BuiltInHolidayCalendar.entries2026.count)
    }
}
