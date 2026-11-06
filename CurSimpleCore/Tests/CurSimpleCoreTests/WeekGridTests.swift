import Testing
@testable import CurSimpleCore

@Suite("Week grid layout")
struct WeekGridTests {

    @Test("Overlapping courses share the column")
    func overlapLanes() {
        let first = makeCourse(id: "a", day: 1, start: 1, end: 2)
        let second = makeCourse(id: "b", day: 1, start: 2, end: 3)

        let blocks = weekGridBlocks(courses: [first, second], week: 1)

        #expect(blocks.count == 2)
        #expect(blocks.allSatisfy { $0.laneCount == 2 })
        #expect(Set(blocks.map(\.lane)) == [0, 1])
    }

    @Test("Non-overlapping courses use the full column")
    func singleLanes() {
        let first = makeCourse(id: "a", day: 1, start: 1, end: 2)
        let second = makeCourse(id: "b", day: 1, start: 3, end: 4)

        let blocks = weekGridBlocks(courses: [first, second], week: 1)
        #expect(blocks.allSatisfy { $0.laneCount == 1 && $0.lane == 0 })
    }

    @Test("Three overlapping courses get three lanes")
    func threeLanes() {
        let courses = [
            makeCourse(id: "a", day: 2, start: 1, end: 4),
            makeCourse(id: "b", day: 2, start: 2, end: 3),
            makeCourse(id: "c", day: 2, start: 3, end: 5),
        ]
        let blocks = weekGridBlocks(courses: courses, week: 1)
        #expect(blocks.count == 3)
        #expect(blocks.allSatisfy { $0.laneCount == 3 })
        #expect(Set(blocks.map(\.lane)) == [0, 1, 2])
    }

    @Test("Courses outside the week are excluded")
    func weekFiltering() {
        let odd = makeCourse(id: "a", weeks: [1, 3])
        let even = makeCourse(id: "b", weeks: [2, 4])

        #expect(weekGridBlocks(courses: [odd, even], week: 1).map(\.id) == ["a"])
        #expect(weekGridBlocks(courses: [odd, even], week: 2).map(\.id) == ["b"])
        #expect(weekGridBlocks(courses: [odd, even], week: 3).map(\.id) == ["a"])
    }

    @Test("Hidden courses are excluded")
    func hiddenFiltering() {
        var hidden = makeCourse(id: "a")
        hidden.hidden = true
        #expect(weekGridBlocks(courses: [hidden], week: 1).isEmpty)
    }

    @Test("Node count covers courses beyond the profile")
    func nodeCount() {
        let profile = TimingProfile(id: "p", slots: [
            ClassSlotTime(startNode: 1, endNode: 1, startTime: "08:00", endTime: "08:45"),
        ])
        #expect(weekGridNodeCount(profile: profile, courses: []) == 1)
        #expect(weekGridNodeCount(profile: profile, courses: [makeCourse(start: 1, end: 6)]) == 6)
        #expect(weekGridNodeCount(profile: .defaultProfile(), courses: []) == 11)
    }
}
