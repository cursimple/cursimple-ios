import Testing
@testable import CurSimpleCore

@Suite("Course conflicts")
struct ConflictTests {

    @Test("Overlapping periods in the same day conflict")
    func periodOverlap() {
        let first = makeCourse(id: "a", title: "高数", day: 1, start: 1, end: 2)
        let second = makeCourse(id: "b", title: "英语", day: 1, start: 2, end: 3)

        let conflict = courseConflictOrNull(first, second)

        #expect(conflict?.overlappingNodes == 2...2)
        #expect(conflict?.overlappingWeeks.count == defaultTermWeekCount)
        #expect(conflict?.kind == .courseVsCourse)
    }

    @Test("Adjacent periods do not conflict")
    func adjacentPeriods() {
        let first = makeCourse(id: "a", day: 1, start: 1, end: 2)
        let second = makeCourse(id: "b", day: 1, start: 3, end: 4)
        #expect(courseConflictOrNull(first, second) == nil)
    }

    @Test("Different days never conflict")
    func differentDays() {
        let first = makeCourse(id: "a", day: 1)
        let second = makeCourse(id: "b", day: 2)
        #expect(courseConflictOrNull(first, second) == nil)
    }

    @Test("Disjoint explicit weeks do not conflict")
    func disjointWeeks() {
        let first = makeCourse(id: "a", weeks: [1, 3, 5])
        let second = makeCourse(id: "b", weeks: [2, 4, 6])
        #expect(courseConflictOrNull(first, second) == nil)

        let odd = makeCourse(id: "c", weeks: [1, 3])
        let alsoOdd = makeCourse(id: "d", weeks: [3, 7])
        #expect(courseConflictOrNull(odd, alsoOdd)?.overlappingWeeks == [3])
    }

    @Test("Empty weeks mean every week up to the bound")
    func implicitEveryWeek() {
        let every = makeCourse(id: "a", weeks: [])
        let later = makeCourse(id: "b", weeks: [25])
        #expect(termWeekIntersection(every.weeks, later.weeks, maxWeekCount: 20) == [25])
    }

    @Test("Hidden courses are excluded")
    func hiddenExcluded() {
        var hidden = makeCourse(id: "b")
        hidden.hidden = true
        #expect(courseConflictOrNull(makeCourse(id: "a"), hidden) == nil)
    }

    @Test("Exam conflicts report their kind")
    func examKind() {
        let exam = makeCourse(id: "a", category: .exam)
        let course = makeCourse(id: "b")
        #expect(courseConflictOrNull(exam, course)?.kind == .examVsCourse)
        #expect(courseConflictOrNull(exam, makeCourse(id: "c", category: .exam))?.kind == .examVsExam)
    }

    @Test("Conflicts are reported once and sorted")
    func conflictList() {
        let courses = [
            makeCourse(id: "a", title: "B", day: 2, start: 1, end: 2),
            makeCourse(id: "b", title: "A", day: 2, start: 2, end: 3),
            makeCourse(id: "c", title: "C", day: 1, start: 3, end: 4),
        ]
        let conflicts = findCourseConflicts(courses)
        #expect(conflicts.count == 1)
        #expect(conflicts.first?.dayOfWeek == 2)
    }

    @Test("Week ranges compress consecutive numbers")
    func weekRangesCompress() {
        #expect(weekRanges([1, 2, 3, 5, 7, 8]) == [1...3, 5...5, 7...8])
        #expect(weekRanges([]).isEmpty)
        #expect(weekRanges([0, -1]).isEmpty)
    }
}
