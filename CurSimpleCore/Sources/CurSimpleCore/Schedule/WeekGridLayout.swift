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

/// Courses that touch in the same day, drawn as one stacked card with a count badge.
public struct GridCourseCluster: Identifiable, Hashable, Sendable {

    public let courses: [CourseItem]

    public init(courses: [CourseItem]) {
        self.courses = courses
    }

    public var id: String { courses.map(\.id).joined(separator: "|") }
    public var primary: CourseItem { courses[0] }
    public var count: Int { courses.count }
}

/// Overlapping courses grouped for the stacked presentation.
public func weekGridClusters(courses: [CourseItem], week: Int) -> [GridCourseCluster] {
    let active = courses.filter { !$0.hidden && $0.isActive(inWeek: week) }
    _ = active
    return weekGridClustersLegacy(courses: courses, week: week)
}

/// Legacy simple filter kept for the plain path.
private func weekGridClustersLegacy(courses: [CourseItem], week: Int) -> [GridCourseCluster] {
    let active = courses.filter { !$0.hidden && $0.isActive(inWeek: week) }
    var clusters: [GridCourseCluster] = []

    for day in 1...7 {
        let dayCourses = active
            .filter { $0.time.dayOfWeek == day }
            .sorted {
                ($0.time.nodeRange.lowerBound, $0.time.nodeRange.upperBound, $0.id)
                    < ($1.time.nodeRange.lowerBound, $1.time.nodeRange.upperBound, $1.id)
            }

        var groups: [[CourseItem]] = []
        for course in dayCourses {
            var merged = [course]
            var remaining: [[CourseItem]] = []
            for group in groups {
                if group.contains(where: { overlaps($0.time.nodeRange, course.time.nodeRange) }) {
                    merged.append(contentsOf: group)
                } else {
                    remaining.append(group)
                }
            }
            groups = remaining + [merged]
        }

        for group in groups {
            let sorted = group.sorted {
                ($0.time.nodeRange.lowerBound, $0.time.nodeRange.upperBound, $0.id)
                    < ($1.time.nodeRange.lowerBound, $1.time.nodeRange.upperBound, $1.id)
            }
            clusters.append(GridCourseCluster(courses: sorted))
        }
    }

    return clusters
}

/// Total rows the grid must render, including nodes referenced only by courses.
public func weekGridNodeCount(profile: TimingProfile, courses: [CourseItem]) -> Int {
    let courseMax = courses
        .filter { !$0.hidden }
        .map { $0.time.nodeRange.upperBound }
        .max() ?? 0
    return max(profile.maxNode, courseMax, 1)
}


/// Clusters for one visible day under holidays and overrides, with a per-day origin label.
public struct DayGridContent: Hashable, Sendable {

    public let clusters: [GridCourseCluster]
    public let resolution: ScheduleDayResolution

    public init(clusters: [GridCourseCluster], resolution: ScheduleDayResolution) {
        self.clusters = clusters
        self.resolution = resolution
    }

    public var isHoliday: Bool { resolution.isHoliday }
    public var holidayName: String? { resolution.holidayName }
}

public func dayGridContent(
    date: Date,
    courses: [CourseItem],
    overrides: [TemporaryScheduleOverride],
    holidayCalendar: HolidayCalendarSettings,
    termStartDate: Date?,
    calendar: Calendar = .current
) -> DayGridContent {
    let resolution = resolveScheduleDay(
        date: date,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        calendar: calendar
    )
    let scheduled = coursesScheduledOn(
        date: date,
        courses: courses,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        termStartDate: termStartDate,
        includeCancelled: false,
        calendar: calendar
    )
    let sorted = scheduled.sorted {
        ($0.time.startNode, $0.time.endNode, $0.id) < ($1.time.startNode, $1.time.endNode, $1.id)
    }

    var clusters: [GridCourseCluster] = []
    for course in sorted {
        var merged = [course]
        var remaining: [GridCourseCluster] = []
        for cluster in clusters {
            let touches = cluster.courses.contains {
                $0.time.nodeRange.lowerBound <= course.time.nodeRange.upperBound
                    && course.time.nodeRange.lowerBound <= $0.time.nodeRange.upperBound
            }
            if touches {
                merged.append(contentsOf: cluster.courses)
            } else {
                remaining.append(cluster)
            }
        }
        clusters = remaining + [GridCourseCluster(courses: merged.sorted {
            ($0.time.startNode, $0.time.endNode, $0.id) < ($1.time.startNode, $1.time.endNode, $1.id)
        })]
    }

    return DayGridContent(clusters: clusters, resolution: resolution)
}
