import Foundation

public struct AppPreferences: Codable, Hashable, Sendable {

    public var accent: AccentTheme
    public var paletteStyle: CoursePaletteStyle
    public var weekStart: WeekStartDay
    public var showWeekend: Bool
    public var showSaturday: Bool

    public init(
        accent: AccentTheme = .green,
        paletteStyle: CoursePaletteStyle = .standard,
        weekStart: WeekStartDay = .monday,
        showWeekend: Bool = true,
        showSaturday: Bool = true
    ) {
        self.accent = accent
        self.paletteStyle = paletteStyle
        self.weekStart = weekStart
        self.showWeekend = showWeekend
        self.showSaturday = showSaturday
    }

    private enum CodingKeys: String, CodingKey {
        case accent, paletteStyle, weekStart, showWeekend, showSaturday
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accent = (try? container.decodeIfPresent(AccentTheme.self, forKey: .accent)) ?? .green
        paletteStyle = (try? container.decodeIfPresent(CoursePaletteStyle.self, forKey: .paletteStyle)) ?? .standard
        weekStart = (try? container.decodeIfPresent(WeekStartDay.self, forKey: .weekStart)) ?? .monday
        showWeekend = try container.decodeIfPresent(Bool.self, forKey: .showWeekend) ?? true
        showSaturday = try container.decodeIfPresent(Bool.self, forKey: .showSaturday) ?? true
    }
}

public struct AppState: Codable, Sendable {

    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var terms: [Term]
    public var activeTermID: String
    public var timingProfiles: [TimingProfile]
    public var activeTimingProfileID: String
    public var preferences: AppPreferences
    public var memos: [MemoNote]

    public init(
        schemaVersion: Int = AppState.currentSchemaVersion,
        terms: [Term] = [],
        activeTermID: String = "",
        timingProfiles: [TimingProfile] = [],
        activeTimingProfileID: String = "",
        preferences: AppPreferences = .init(),
        memos: [MemoNote] = []
    ) {
        self.schemaVersion = schemaVersion
        self.terms = terms
        self.activeTermID = activeTermID
        self.timingProfiles = timingProfiles
        self.activeTimingProfileID = activeTimingProfileID
        self.preferences = preferences
        self.memos = memos
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, terms, activeTermID, timingProfiles, activeTimingProfileID, preferences, memos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        terms = try container.decodeIfPresent([Term].self, forKey: .terms) ?? []
        activeTermID = try container.decodeIfPresent(String.self, forKey: .activeTermID) ?? ""
        timingProfiles = try container.decodeIfPresent([TimingProfile].self, forKey: .timingProfiles) ?? []
        activeTimingProfileID = try container.decodeIfPresent(String.self, forKey: .activeTimingProfileID) ?? ""
        preferences = (try? container.decodeIfPresent(AppPreferences.self, forKey: .preferences)) ?? .init()
        memos = try container.decodeIfPresent([MemoNote].self, forKey: .memos) ?? []
    }

    public var activeTerm: Term? {
        terms.first { $0.id == activeTermID } ?? terms.first
    }

    public var activeTimingProfile: TimingProfile? {
        timingProfiles.first { $0.id == activeTimingProfileID } ?? timingProfiles.first
    }
}
