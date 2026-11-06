import Foundation

public let defaultTermWeekCount = 20

public enum CourseConflictKind: String, Codable, Sendable {
    case courseVsCourse
    case examVsCourse
    case examVsExam
}

public struct CourseConflict: Hashable, Sendable, Identifiable {

    public let first: CourseItem
    public let second: CourseItem
    public let dayOfWeek: Int
    public let overlappingNodes: ClosedRange<Int>
    public let overlappingWeeks: [Int]

    public init(
        first: CourseItem,
        second: CourseItem,
        dayOfWeek: Int,
        overlappingNodes: ClosedRange<Int>,
        overlappingWeeks: [Int]
    ) {
        self.first = first
        self.second = second
        self.dayOfWeek = dayOfWeek
        self.overlappingNodes = overlappingNodes
        self.overlappingWeeks = overlappingWeeks
    }

    public var id: String {
        "\(first.id)|\(second.id)|\(dayOfWeek)|\(overlappingNodes.lowerBound)-\(overlappingNodes.upperBound)"
    }

    public var kind: CourseConflictKind {
        switch (first.category, second.category) {
        case (.exam, .exam): .examVsExam
        case (.exam, _), (_, .exam): .examVsCourse
        default: .courseVsCourse
        }
    }
}

/// Expand explicit weeks, or every positive week through the larger bound.
public func termWeekIntersection(
    _ first: [Int],
    _ second: [Int],
    maxWeekCount: Int = defaultTermWeekCount
) -> [Int] {
    let explicitMax = (first + second).filter { $0 >= 1 }.max() ?? 0
    let bound = max(maxWeekCount, explicitMax, 1)

    func expand(_ weeks: [Int]) -> [Int] {
        if weeks.isEmpty {
            return Array(1...bound)
        }
        return Array(Set(weeks.filter { $0 >= 1 })).sorted()
    }

    let right = Set(expand(second))
    return expand(first).filter { right.contains($0) }
}

/// Period intersection, or nil when the ranges only touch at a boundary.
private func intersectNodeRanges(
    _ first: ClosedRange<Int>,
    _ second: ClosedRange<Int>
) -> ClosedRange<Int>? {
    let start = max(first.lowerBound, second.lowerBound)
    let end = min(first.upperBound, second.upperBound)
    return start <= end ? start...end : nil
}

public func courseConflictOrNull(
    _ first: CourseItem,
    _ second: CourseItem,
    maxWeekCount: Int = defaultTermWeekCount
) -> CourseConflict? {
    guard first.id != second.id else { return nil }
    guard !first.hidden, !second.hidden else { return nil }
    guard first.time.dayOfWeek == second.time.dayOfWeek else { return nil }
    guard let nodes = intersectNodeRanges(first.time.nodeRange, second.time.nodeRange) else { return nil }
    let weeks = termWeekIntersection(first.weeks, second.weeks, maxWeekCount: maxWeekCount)
    guard !weeks.isEmpty else { return nil }
    return CourseConflict(
        first: first,
        second: second,
        dayOfWeek: first.time.dayOfWeek,
        overlappingNodes: nodes,
        overlappingWeeks: weeks
    )
}

/// Report each pair once, sorted by day, start period and title.
public func findCourseConflicts(
    _ courses: [CourseItem],
    maxWeekCount: Int = defaultTermWeekCount
) -> [CourseConflict] {
    var seen = Set<String>()
    let candidates = courses.filter { !$0.hidden && seen.insert($0.id).inserted }
    var conflicts: [CourseConflict] = []
    for i in candidates.indices {
        for j in (i + 1)..<candidates.endIndex {
            if let conflict = courseConflictOrNull(candidates[i], candidates[j], maxWeekCount: maxWeekCount) {
                conflicts.append(conflict)
            }
        }
    }
    return conflicts.sorted {
        ($0.dayOfWeek, $0.overlappingNodes.lowerBound, $0.first.title, $0.second.title)
            < ($1.dayOfWeek, $1.overlappingNodes.lowerBound, $1.first.title, $1.second.title)
    }
}

/// Compare an unsaved candidate against stored courses; `first` always refers to the candidate.
public func conflicts(
    with candidate: CourseItem,
    in others: [CourseItem],
    maxWeekCount: Int = defaultTermWeekCount
) -> [CourseConflict] {
    var seen = Set<String>()
    return others
        .filter { seen.insert($0.id).inserted }
        .compactMap { courseConflictOrNull(candidate, $0, maxWeekCount: maxWeekCount) }
        .sorted {
            ($0.overlappingNodes.lowerBound, $0.second.title)
                < ($1.overlappingNodes.lowerBound, $1.second.title)
        }
}

/// Compress sorted week numbers into consecutive ranges.
public func weekRanges(_ weeks: [Int]) -> [ClosedRange<Int>] {
    let normalized = Array(Set(weeks.filter { $0 >= 1 })).sorted()
    guard let first = normalized.first else { return [] }
    var ranges: [ClosedRange<Int>] = []
    var lower = first
    var upper = first
    for week in normalized.dropFirst() {
        if week == upper + 1 {
            upper = week
        } else {
            ranges.append(lower...upper)
            lower = week
            upper = week
        }
    }
    ranges.append(lower...upper)
    return ranges
}
