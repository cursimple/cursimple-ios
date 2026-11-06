import Foundation

public enum MemoPriority: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case low
    case medium
    case high

    public var id: String { rawValue }

    public var rank: Int {
        switch self {
        case .none: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }

    public var localizationKey: String { "memo.priority.\(rawValue)" }
}

public struct ChecklistProgress: Hashable, Sendable {
    public let done: Int
    public let total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }

    public var hasItems: Bool { total > 0 }
    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

public struct MemoNote: Codable, Identifiable, Hashable, Sendable {

    public var id: String
    /// Course association key; nil denotes a general note.
    public var courseKey: String?
    public var courseTitle: String
    public var title: String
    public var body: String
    public var priority: MemoPriority
    public var pinned: Bool
    /// ISO-8601 local date-time, `yyyy-MM-ddTHH:mm`.
    public var dueAt: String?
    public var completed: Bool
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: String = UUID().uuidString,
        courseKey: String? = nil,
        courseTitle: String = "",
        title: String = "",
        body: String = "",
        priority: MemoPriority = .none,
        pinned: Bool = false,
        dueAt: String? = nil,
        completed: Bool = false,
        createdAt: Int64 = 0,
        updatedAt: Int64 = 0
    ) {
        self.id = id
        self.courseKey = courseKey
        self.courseTitle = courseTitle
        self.title = title
        self.body = body
        self.priority = priority
        self.pinned = pinned
        self.dueAt = dueAt
        self.completed = completed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, courseKey, courseTitle, title, body, priority, pinned, dueAt, completed, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        courseKey = try container.decodeIfPresent(String.self, forKey: .courseKey)
        courseTitle = try container.decodeIfPresent(String.self, forKey: .courseTitle) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        priority = (try? container.decodeIfPresent(MemoPriority.self, forKey: .priority)) ?? .none
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        createdAt = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
    }

    public var isBlank: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
            && body.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var checklist: ChecklistProgress {
        MemoChecklist.progress(of: body)
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body.split(separator: "\n", omittingEmptySubsequences: true).first
            .map(String.init) ?? ""
        return String(firstLine.trimmingCharacters(in: .whitespaces).prefix(40))
    }
}

public enum MemoChecklist {

    /// Markdown checkbox line; accepts indentation, dash or star bullets, either-case x.
    public static func parseLine(_ line: String) -> (checked: Bool, text: String)? {
        let pattern = "^(\\s*[-*]\\s+\\[)([ xX])(]\\s?)(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 5,
              let checkRange = Range(match.range(at: 2), in: line),
              let textRange = Range(match.range(at: 4), in: line) else {
            return nil
        }
        let marker = line[checkRange]
        return (marker != " ", String(line[textRange]))
    }

    public static func progress(of body: String) -> ChecklistProgress {
        var done = 0
        var total = 0
        body.enumerateLines { line, _ in
            guard let parsed = parseLine(line) else { return }
            total += 1
            if parsed.checked { done += 1 }
        }
        return ChecklistProgress(done: done, total: total)
    }

    /// Toggle the checkbox at `lineIndex`; non-checkbox lines pass through untouched.
    public static func togglingLine(_ body: String, lineIndex: Int) -> String {
        var lines = body.components(separatedBy: "\n")
        guard lines.indices.contains(lineIndex),
              let parsed = parseLine(lines[lineIndex]) else {
            return body
        }
        // Rebuild from the regex's own groups so exotic bullets keep their shape.
        let regex = try! NSRegularExpression(pattern: "^(\\s*[-*]\\s+\\[)([ xX])(]\\s?)(.*)$")
        let original = lines[lineIndex]
        let range = NSRange(original.startIndex..., in: original)
        guard let match = regex.firstMatch(in: original, range: range),
              match.numberOfRanges == 5,
              let headRange = Range(match.range(at: 1), in: original),
              let markerRange = Range(match.range(at: 2), in: original),
              let tailRange = Range(match.range(at: 3), in: original) else {
            return body
        }
        let newMarker: String = parsed.checked ? " " : "x"
        // Splice head (up to "[") + the new marker + the original tail starting
        // at "]" — everything from group 3 on survives untouched.
        let textAfterMarker: Substring
        if tailRange.lowerBound > markerRange.upperBound {
            textAfterMarker = original[markerRange.upperBound...]
        } else {
            // Group 3 starts at or before the marker end only when the marker is
            // empty; the "]" then lives right here.
            textAfterMarker = original[tailRange.lowerBound...]
        }
        lines[lineIndex] = String(original[headRange]) + newMarker + String(textAfterMarker)
        return lines.joined(separator: "\n")
    }

    /// Toggle the checkbox for a line matching the given text, or append a new checkbox line.
    public static func togglingItem(_ body: String, text: String) -> String {
        let lines = body.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if let parsed = parseLine(line), parsed.text == text {
                return togglingLine(body, lineIndex: index)
            }
        }
        if body.isEmpty { return "- [ ] " + text }
        if body.hasSuffix("\n") { return body + "- [ ] " + text }
        return body + "\n" + "- [ ] " + text
    }

    /// Insert a checkbox line after the last existing checkbox, or at the end.
    /// Trailing newlines in the body are preserved verbatim.
    public static func appendingItem(_ body: String, text: String) -> String {
        guard !body.isEmpty else { return "- [ ] " + text }

        let trailing = body.count - body.drop(while: { $0.isNewline ? false : false }).count
        let trailingNewlines = body.reversed().prefix { $0 == "\n" }.count
        let core = String(body.dropLast(trailingNewlines))
        let lines = core.components(separatedBy: "\n")

        var insertAt = lines.count
        for (index, line) in lines.enumerated() where parseLine(line) != nil {
            insertAt = index + 1
        }
        var next = lines
        next.insert("- [ ] " + text, at: insertAt)
        let joined = next.joined(separator: "\n")
        return joined + String(repeating: "\n", count: trailingNewlines)
    }
}

public func memoCourseKey(_ courseTitle: String) -> String {
    courseTitle.trimmingCharacters(in: .whitespaces).lowercased()
}

public enum MemoDueState: Comparable, Sendable {
    case none
    case overdue
    case today
    case soon
    case later

    var order: Int {
        switch self {
        case .overdue: 0
        case .today: 1
        case .soon: 2
        case .none, .later: 3
        }
    }

    public static func < (lhs: MemoDueState, rhs: MemoDueState) -> Bool {
        lhs.order < rhs.order
    }
}

public extension MemoNote {

    /// Nil when the stored string cannot be read as a local date-time.
    /// Wall-clock parse: the resulting Date is only compared through the same
    /// calendar that `dueState(at:calendar:)` uses, never against raw instants
    /// from another zone.
    func dueDateTime(calendar: Calendar = .current) -> Date? {
        guard let dueAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: dueAt)
    }

    func dueState(at now: Date, calendar: Calendar = .current) -> MemoDueState {
        guard let due = dueDateTime(calendar: calendar) else { return .none }
        if completed { return .later }
        if due < now { return .overdue }
        if calendar.isDate(due, inSameDayAs: now) { return .today }
        if let threeDays = calendar.date(byAdding: .day, value: 3, to: now), due < threeDays {
            return .soon
        }
        return .later
    }
}

/// Pinned first, completed last; remaining notes sort by deadline, priority and latest edit.
public func memoComparator(now: Date, calendar: Calendar = .current) -> (MemoNote, MemoNote) -> Bool {
    { lhs, rhs in
        if lhs.completed != rhs.completed { return !lhs.completed }
        let lhsPinned = lhs.pinned && !lhs.completed
        let rhsPinned = rhs.pinned && !rhs.completed
        if lhsPinned != rhsPinned { return lhsPinned }

        let lhsDue = lhs.dueState(at: now, calendar: calendar)
        let rhsDue = rhs.dueState(at: now, calendar: calendar)
        if lhsDue != rhsDue { return lhsDue < rhsDue }

        if lhs.completed {
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        } else {
            let lhsDate = lhs.dueDateTime(calendar: calendar) ?? .distantFuture
            let rhsDate = rhs.dueDateTime(calendar: calendar) ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            if lhs.priority.rank != rhs.priority.rank { return lhs.priority.rank > rhs.priority.rank }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        }
        return lhs.id < rhs.id
    }
}
