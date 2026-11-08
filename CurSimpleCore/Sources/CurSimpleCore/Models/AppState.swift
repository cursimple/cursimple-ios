import Foundation

public struct AppPreferences: Codable, Hashable, Sendable {

    public var accent: AccentTheme
    public var paletteStyle: CoursePaletteStyle
    public var weekStart: WeekStartDay
    public var showWeekend: Bool
    public var showSaturday: Bool
    public var reminders: ReminderPreferences
    public var display: ScheduleDisplayPreferences

    public init(
        accent: AccentTheme = .green,
        paletteStyle: CoursePaletteStyle = .standard,
        weekStart: WeekStartDay = .monday,
        showWeekend: Bool = true,
        showSaturday: Bool = true,
        reminders: ReminderPreferences = .init(),
        display: ScheduleDisplayPreferences = .init()
    ) {
        self.accent = accent
        self.paletteStyle = paletteStyle
        self.weekStart = weekStart
        self.showWeekend = showWeekend
        self.showSaturday = showSaturday
        self.reminders = reminders
        self.display = display
    }

    private enum CodingKeys: String, CodingKey {
        case accent, paletteStyle, weekStart, showWeekend, showSaturday, reminders, display
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accent = (try? container.decodeIfPresent(AccentTheme.self, forKey: .accent)) ?? .green
        paletteStyle = (try? container.decodeIfPresent(CoursePaletteStyle.self, forKey: .paletteStyle)) ?? .standard
        weekStart = (try? container.decodeIfPresent(WeekStartDay.self, forKey: .weekStart)) ?? .monday
        showWeekend = try container.decodeIfPresent(Bool.self, forKey: .showWeekend) ?? true
        showSaturday = try container.decodeIfPresent(Bool.self, forKey: .showSaturday) ?? true
        reminders = (try? container.decodeIfPresent(ReminderPreferences.self, forKey: .reminders)) ?? .init()
        display = (try? container.decodeIfPresent(ScheduleDisplayPreferences.self, forKey: .display)) ?? .init()
    }
}

public struct AppState: Codable, Equatable, Sendable {

    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var terms: [Term]
    public var activeTermID: String
    public var timingProfiles: [TimingProfile]
    public var activeTimingProfileID: String
    public var preferences: AppPreferences
    public var memos: [MemoNote]
    public var holidayCalendar: HolidayCalendarSettings
    public var overrides: [TemporaryScheduleOverride]
    public var alarms: [Alarm]

    public init(
        schemaVersion: Int = AppState.currentSchemaVersion,
        terms: [Term] = [],
        activeTermID: String = "",
        timingProfiles: [TimingProfile] = [],
        activeTimingProfileID: String = "",
        preferences: AppPreferences = .init(),
        memos: [MemoNote] = [],
        holidayCalendar: HolidayCalendarSettings = .init(),
        overrides: [TemporaryScheduleOverride] = [],
        alarms: [Alarm] = []
    ) {
        self.schemaVersion = schemaVersion
        self.terms = terms
        self.activeTermID = activeTermID
        self.timingProfiles = timingProfiles
        self.activeTimingProfileID = activeTimingProfileID
        self.preferences = preferences
        self.memos = memos
        self.holidayCalendar = holidayCalendar
        self.overrides = overrides
        self.alarms = alarms
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, terms, activeTermID, timingProfiles, activeTimingProfileID, preferences, memos, holidayCalendar, overrides, alarms
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
        holidayCalendar = (try? container.decodeIfPresent(HolidayCalendarSettings.self, forKey: .holidayCalendar)) ?? .init()
        overrides = try container.decodeIfPresent([TemporaryScheduleOverride].self, forKey: .overrides) ?? []
        alarms = try container.decodeIfPresent([Alarm].self, forKey: .alarms) ?? []
    }

    public var activeTerm: Term? {
        terms.first { $0.id == activeTermID } ?? terms.first
    }

    public var activeTimingProfile: TimingProfile? {
        timingProfiles.first { $0.id == activeTimingProfileID } ?? timingProfiles.first
    }
}
