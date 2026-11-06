import Foundation

public enum HolidayEntryKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case holiday
    case workday

    public var id: String { rawValue }
}

public struct HolidayCalendarEntry: Codable, Hashable, Sendable, Identifiable {
    /// `yyyy-MM-dd`
    public var date: String
    public var kind: HolidayEntryKind
    public var name: String

    public init(date: String, kind: HolidayEntryKind = .holiday, name: String = "") {
        self.date = date
        self.kind = kind
        self.name = name
    }

    public var id: String { date }

    public var dateValue: Date? {
        DateOnly.parse(date)
    }
}

/// One year's published holiday declarations, replacing the bundled snapshot for that year.
public struct SyncedHolidayYear: Codable, Hashable, Sendable {
    public var year: Int
    public var entries: [HolidayCalendarEntry]
    public var fetchedAt: String
    public var source: String

    public init(year: Int, entries: [HolidayCalendarEntry] = [], fetchedAt: String = "", source: String = "") {
        self.year = year
        self.entries = entries
        self.fetchedAt = fetchedAt
        self.source = source
    }
}

/// User entries override synced data for the same day; synced data replaces the bundled year.
public struct HolidayCalendarSettings: Codable, Hashable, Sendable {

    public var builtInEnabled: Bool
    public var entries: [HolidayCalendarEntry]
    public var syncedYears: [SyncedHolidayYear]

    public init(
        builtInEnabled: Bool = true,
        entries: [HolidayCalendarEntry] = [],
        syncedYears: [SyncedHolidayYear] = []
    ) {
        self.builtInEnabled = builtInEnabled
        self.entries = entries
        self.syncedYears = syncedYears
    }

    private enum CodingKeys: String, CodingKey {
        case builtInEnabled, entries, syncedYears
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        builtInEnabled = try container.decodeIfPresent(Bool.self, forKey: .builtInEnabled) ?? true
        entries = try container.decodeIfPresent([HolidayCalendarEntry].self, forKey: .entries) ?? []
        syncedYears = try container.decodeIfPresent([SyncedHolidayYear].self, forKey: .syncedYears) ?? []
    }

    public func userEntry(on date: Date, calendar: Calendar = .current) -> HolidayCalendarEntry? {
        let key = DateOnly.string(from: date, calendar: calendar)
        return entries.last { $0.date == key }
    }

    public func syncedEntry(on date: Date, calendar: Calendar = .current) -> HolidayCalendarEntry? {
        guard builtInEnabled else { return nil }
        let year = calendar.component(.year, from: date)
        guard let synced = syncedYears.last(where: { $0.year == year }) else { return nil }
        let key = DateOnly.string(from: date, calendar: calendar)
        return synced.entries.last { $0.date == key }
    }

    public func hasSyncedYear(_ year: Int) -> Bool {
        syncedYears.contains { $0.year == year && !$0.entries.isEmpty }
    }

    /// Bundled data applies only without synced coverage for that year.
    public func builtInEntry(on date: Date, calendar: Calendar = .current) -> HolidayCalendarEntry? {
        guard builtInEnabled else { return nil }
        let year = calendar.component(.year, from: date)
        guard !hasSyncedYear(year) else { return nil }
        let key = DateOnly.string(from: date, calendar: calendar)
        return BuiltInHolidayCalendar.index[key]
    }

    public func upsertingUser(_ entry: HolidayCalendarEntry) -> HolidayCalendarSettings {
        var next = self
        next.entries.removeAll { $0.date == entry.date }
        next.entries.append(entry)
        return next
    }

    public func removingUserEntry(date: String) -> HolidayCalendarSettings {
        var next = self
        next.entries.removeAll { $0.date == date }
        return next
    }

    public func replacingSyncedYear(_ year: SyncedHolidayYear) -> HolidayCalendarSettings {
        var next = self
        next.syncedYears.removeAll { $0.year == year.year }
        next.syncedYears.append(year)
        return next
    }
}

/// Bundled public holiday fallback; make-up workdays stay user-configured.
public enum BuiltInHolidayCalendar {

    /// (date, kind, name) — 2026 declarations matching the shared dataset.
    static let entries2026: [(String, HolidayEntryKind, String)] = [
        ("2026-01-01", .holiday, "元旦"), ("2026-01-02", .holiday, "元旦"), ("2026-01-03", .holiday, "元旦"),
        ("2026-02-15", .holiday, "春节"), ("2026-02-16", .holiday, "除夕"), ("2026-02-17", .holiday, "春节"),
        ("2026-02-18", .holiday, "春节"), ("2026-02-19", .holiday, "春节"), ("2026-02-20", .holiday, "春节"),
        ("2026-02-21", .holiday, "春节"), ("2026-02-22", .holiday, "春节"), ("2026-02-23", .holiday, "春节"),
        ("2026-04-04", .holiday, "清明节"), ("2026-04-05", .holiday, "清明节"), ("2026-04-06", .holiday, "清明节"),
        ("2026-05-01", .holiday, "劳动节"), ("2026-05-02", .holiday, "劳动节"), ("2026-05-03", .holiday, "劳动节"),
        ("2026-05-04", .holiday, "劳动节"), ("2026-05-05", .holiday, "劳动节"),
        ("2026-06-19", .holiday, "端午节"), ("2026-06-20", .holiday, "端午节"), ("2026-06-21", .holiday, "端午节"),
        ("2026-09-25", .holiday, "中秋节"), ("2026-09-26", .holiday, "中秋节"), ("2026-09-27", .holiday, "中秋节"),
        ("2026-10-01", .holiday, "国庆节"), ("2026-10-02", .holiday, "国庆节"), ("2026-10-03", .holiday, "国庆节"),
        ("2026-10-04", .holiday, "国庆节"), ("2026-10-05", .holiday, "国庆节"), ("2026-10-06", .holiday, "国庆节"),
        ("2026-10-07", .holiday, "国庆节"),
    ]

    static let index: [String: HolidayCalendarEntry] = {
        var map: [String: HolidayCalendarEntry] = [:]
        for (date, kind, name) in entries2026 {
            map[date] = HolidayCalendarEntry(date: date, kind: kind, name: name)
        }
        return map
    }()

    public static var coveredYears: [Int] {
        Array(Set(index.keys.compactMap { Int($0.prefix(4)) })).sorted()
    }

    public static func entry(on date: Date, calendar: Calendar = .current) -> HolidayCalendarEntry? {
        index[DateOnly.string(from: date, calendar: calendar)]
    }

    public static func entries(ofYear year: Int) -> [HolidayCalendarEntry] {
        index.values
            .filter { $0.date.hasPrefix("\(year)-") }
            .sorted { $0.date < $1.date }
    }
}

/// Parse a downloaded holiday dataset; skip individually invalid dates.
public enum HolidayDatasetParser {

    public enum ParseResult: Equatable, Sendable {
        case success(year: Int, entries: [HolidayCalendarEntry])
        case malformed
        case empty
        case yearMismatch(expected: Int, actual: Int)
    }

    public static func parse(_ body: String, expectedYear: Int) -> ParseResult {
        struct RawDay: Decodable {
            var name: String?
            var date: String?
            var isOffDay: Bool?
        }
        struct RawDataset: Decodable {
            var year: Int?
            var days: [RawDay]?
        }

        guard let data = body.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawDataset.self, from: data) else {
            return .malformed
        }
        guard let year = raw.year, year == expectedYear else {
            return .yearMismatch(expected: expectedYear, actual: raw.year ?? -1)
        }

        var seen = Set<String>()
        var entries: [HolidayCalendarEntry] = []
        for day in raw.days ?? [] {
            guard let date = day.date, DateOnly.parse(date) != nil, date.hasPrefix("\(year)-") else {
                continue
            }
            guard seen.insert(date).inserted else { continue }
            entries.append(HolidayCalendarEntry(
                date: date,
                kind: (day.isOffDay ?? true) ? .holiday : .workday,
                name: (day.name ?? "").trimmingCharacters(in: .whitespaces)
            ))
        }
        if entries.isEmpty { return .empty }
        return .success(year: year, entries: entries)
    }
}
