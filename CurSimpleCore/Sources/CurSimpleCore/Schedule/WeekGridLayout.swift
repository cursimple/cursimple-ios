import Foundation

/// One course block in the week grid, with the lane it occupies among overlapping courses.
public struct GridCourseBlock: Identifiable, Hashable, Sendable {

    public let course: CourseItem
    public let lane: Int
    public let laneCount: Int

    public init(course: CourseItem, lane: Int, laneCount: Int) {
        self.course = course
        self.lane = lane
        self.laneCount = laneCount
    }

    public var id: String { course.id }
    public var startNode: Int { course.time.nodeRange.lowerBound }
    public var span: Int { course.time.nodeRange.count }
}

private func overlaps(_ first: ClosedRange<Int>, _ second: ClosedRange<Int>) -> Bool {
    first.lowerBound <= second.upperBound && second.lowerBound <= first.upperBound
}

/**
 Lay out visible courses for one teaching week.

 Courses that touch in the same day form one cluster; the cluster's width is split
 between lanes so nothing is hidden behind another block.
 */
public func weekGridBlocks(courses: [CourseItem], week: Int) -> [GridCourseBlock] {
    let active = courses.filter { !$0.hidden && $0.isActive(inWeek: week) }
    var blocks: [GridCourseBlock] = []

    for day in 1...7 {
        let dayCourses = active
            .filter { $0.time.dayOfWeek == day }
            .sorted {
                ($0.time.nodeRange.lowerBound, $0.time.nodeRange.upperBound, $0.id)
                    < ($1.time.nodeRange.lowerBound, $1.time.nodeRange.upperBound, $1.id)
            }

        var clusters: [[CourseItem]] = []
        for course in dayCourses {
            var merged = [course]
            var remaining: [[CourseItem]] = []
            for cluster in clusters {
                if cluster.contains(where: { overlaps($0.time.nodeRange, course.time.nodeRange) }) {
                    merged.append(contentsOf: cluster)
                } else {
                    remaining.append(cluster)
                }
            }
            clusters = remaining + [merged]
        }

        for cluster in clusters {
            let sorted = cluster.sorted {
                ($0.time.nodeRange.lowerBound, $0.time.nodeRange.upperBound, $0.id)
                    < ($1.time.nodeRange.lowerBound, $1.time.nodeRange.upperBound, $1.id)
            }
            var laneEnds: [Int] = []
            var assignments: [(course: CourseItem, lane: Int)] = []
            for course in sorted {
                let start = course.time.nodeRange.lowerBound
                let end = course.time.nodeRange.upperBound
                if let lane = laneEnds.firstIndex(where: { $0 < start }) {
                    laneEnds[lane] = end
                    assignments.append((course, lane))
                } else {
                    laneEnds.append(end)
                    assignments.append((course, laneEnds.count - 1))
                }
            }
            let laneCount = max(laneEnds.count, 1)
            for assignment in assignments {
                blocks.append(
                    GridCourseBlock(
                        course: assignment.course,
                        lane: assignment.lane,
                        laneCount: laneCount
                    )
                )
            }
        }
    }

    return blocks
}

/// Total rows the grid must render, including nodes referenced only by courses.
public func weekGridNodeCount(profile: TimingProfile, courses: [CourseItem]) -> Int {
    let courseMax = courses
        .filter { !$0.hidden }
        .map { $0.time.nodeRange.upperBound }
        .max() ?? 0
    return max(profile.maxNode, courseMax, 1)
}
