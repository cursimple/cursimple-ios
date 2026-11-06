import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Daily occurrences")
struct OccurrenceTests {

    let calendar = makeTestCalendar()
    let profile = TimingProfile.defaultProfile()

    @Test("Period slots supply the class clock")
    func slotClock() {
        let course = makeCourse(id: "a", day: 1, start: 1, end: 2)
        let items = occurrences(on: testDay("2026-09-07"), courses: [course], week: 1, profile: profile, calendar: calendar)

        #expect(items.count == 1)
        #expect(TimeOfDay(date: items[0].start!, calendar: calendar) == TimeOfDay("08:00"))
        #expect(TimeOfDay(date: items[0].end!, calendar: calendar) == TimeOfDay("09:40"))
        #expect(items[0].hasTime)
    }

    @Test("Typed clock times override period slots")
    func typedClock() {
        var course = makeCourse(id: "a", day: 1, start: 1, end: 2)
        course.reminderStartTime = "18:30"
        course.reminderEndTime = "20:00"

        let item = occurrences(on: testDay("2026-09-07"), courses: [course], week: 1, profile: profile, calendar: calendar)[0]

        #expect(TimeOfDay(date: item.start!, calendar: calendar) == TimeOfDay("18:30"))
        #expect(TimeOfDay(date: item.end!, calendar: calendar) == TimeOfDay("20:00"))
    }

    @Test("Invalid typed times fall back to slots")
    func invalidTypedClock() {
        var course = makeCourse(id: "a", day: 1, start: 1, end: 1)
        course.reminderStartTime = "20:00"
        course.reminderEndTime = "09:00" // reversed, rejected

        let item = occurrences(on: testDay("2026-09-07"), courses: [course], week: 1, profile: profile, calendar: calendar)[0]
        #expect(TimeOfDay(date: item.start!, calendar: calendar) == TimeOfDay("08:00"))
    }

    @Test("Missing period time leaves the course untimed")
    func untimedCourse() {
        let sparse = TimingProfile(id: "sparse", slots: [
            ClassSlotTime(startNode: 1, endNode: 1, startTime: "08:00", endTime: "08:45"),
        ])
        let course = makeCourse(id: "a", day: 1, start: 5, end: 6)
        let item = occurrences(on: testDay("2026-09-07"), courses: [course], week: 1, profile: sparse, calendar: calendar)[0]
        #expect(item.start == nil)
        #expect(!item.hasTime)
    }

    @Test("Week filtering and weekday filtering apply")
    func filters() {
        let mondayWeek1 = makeCourse(id: "a", day: 1, weeks: [1])
        let tuesday = makeCourse(id: "b", day: 2, weeks: [1])
        let mondayWeek2 = makeCourse(id: "c", day: 1, weeks: [2])

        let items = occurrences(
            on: testDay("2026-09-07"), // Monday of week 2
            courses: [mondayWeek1, tuesday, mondayWeek2],
            week: 2,
            profile: profile,
            calendar: calendar
        )
        #expect(items.map(\.course.id) == ["c"])
    }

    @Test("Term date drives the week and pre-term days are empty")
    func termResolution() {
        let term = makeTerm(start: "2026-09-01", courses: [makeCourse(id: "a", day: 1)])
        #expect(occurrences(on: testDay("2026-08-31"), term: term, profile: profile, calendar: calendar).count == 1)
        #expect(occurrences(on: testDay("2026-08-24"), term: term, profile: profile, calendar: calendar).isEmpty)
    }

    @Test("Occurrences sort by clock, untimed last")
    func sorting() {
        var late = makeCourse(id: "late", day: 1, start: 5, end: 5)
        late.reminderStartTime = "16:00"
        late.reminderEndTime = "16:45"
        var early = makeCourse(id: "early", day: 1, start: 1, end: 1)
        early.reminderStartTime = "09:00"
        early.reminderEndTime = "09:45"
        let untimed = makeCourse(id: "untimed", day: 1, start: 12, end: 12)

        let items = occurrences(on: testDay("2026-09-07"), courses: [late, untimed, early], week: 1, profile: profile, calendar: calendar)
        #expect(items.map(\.course.id) == ["early", "late", "untimed"])
    }

    @Test("Week-specific titles, teachers and locations resolve")
    func weekOverrides() {
        var course = makeCourse(id: "a", day: 1, teacher: "张老师", location: "A101")
        course.weekTeachers = ["3": "李老师"]
        course.weekLocations = ["3": "B202"]
        course.weekTitles = ["3": "习题课"]

        let item = occurrences(on: testDay("2026-09-21"), courses: [course], week: 3, profile: profile, calendar: calendar)[0]
        #expect(item.title == "习题课")
        #expect(item.teacher == "李老师")
        #expect(item.location == "B202")
    }
}
