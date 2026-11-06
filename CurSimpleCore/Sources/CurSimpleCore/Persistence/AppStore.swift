import Foundation
import Observation

/// Observable application state with atomic JSON persistence.
@MainActor
@Observable
public final class AppStore {

    public private(set) var state: AppState
    public private(set) var lastError: String?
    public let storageURL: URL

    /// - Parameters:
    ///   - storageURL: Override for tests; defaults to Application Support/CurSimple/state.json.
    ///   - defaultTermName: Localized name for the term created on first launch.
    public init(storageURL: URL? = nil, defaultTermName: String = "CurSimple") {
        let url = storageURL ?? Self.defaultStorageURL()
        self.storageURL = url

        if let loaded = Self.load(from: url) {
            self.state = Self.ensuringUsable(loaded, defaultTermName: defaultTermName)
        } else {
            self.state = Self.seeded(defaultTermName: defaultTermName)
        }
        save()
    }

    public static func defaultStorageURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("CurSimple", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }

    // MARK: - Reading

    public var activeTerm: Term? { state.activeTerm }

    public var timingProfile: TimingProfile {
        state.activeTimingProfile ?? TimingProfile.defaultProfile()
    }

    public var preferences: AppPreferences { state.preferences }

    // MARK: - Mutations

    public func updateTerm(_ term: Term) {
        guard let index = state.terms.firstIndex(where: { $0.id == term.id }) else { return }
        var next = state
        next.terms[index] = term
        commit(next)
    }

    public func addTerm(_ term: Term) {
        var next = state
        next.terms.append(term)
        next.activeTermID = term.id
        commit(next)
    }

    public func selectTerm(id: String) {
        guard state.terms.contains(where: { $0.id == id }) else { return }
        var next = state
        next.activeTermID = id
        commit(next)
    }

    public func addCourse(_ course: CourseItem, termID: String? = nil) {
        var next = state
        guard let index = next.terms.firstIndex(where: { $0.id == (termID ?? next.activeTerm?.id) }) else { return }
        next.terms[index].courses.append(course)
        commit(next)
    }

    public func updateCourse(_ course: CourseItem, termID: String? = nil) {
        var next = state
        guard let index = next.terms.firstIndex(where: { $0.id == (termID ?? next.activeTerm?.id) }),
              let courseIndex = next.terms[index].courses.firstIndex(where: { $0.id == course.id }) else {
            return
        }
        next.terms[index].courses[courseIndex] = course
        commit(next)
    }

    public func deleteCourse(id: String, termID: String? = nil) {
        var next = state
        guard let index = next.terms.firstIndex(where: { $0.id == (termID ?? next.activeTerm?.id) }) else { return }
        next.terms[index].courses.removeAll { $0.id == id }
        commit(next)
    }

    public func setPreferences(_ preferences: AppPreferences) {
        var next = state
        next.preferences = preferences
        commit(next)
    }

    // MARK: - Holidays and overrides

    public func upsertHolidayEntry(_ entry: HolidayCalendarEntry) {
        var next = state
        next.holidayCalendar = next.holidayCalendar.upsertingUser(entry)
        commit(next)
    }

    public func removeHolidayEntry(date: String) {
        var next = state
        next.holidayCalendar = next.holidayCalendar.removingUserEntry(date: date)
        commit(next)
    }

    public func replaceSyncedHolidayYear(_ year: SyncedHolidayYear) {
        var next = state
        next.holidayCalendar = next.holidayCalendar.replacingSyncedYear(year)
        commit(next)
    }

    public func upsertOverride(_ override: TemporaryScheduleOverride) {
        var next = state
        if let index = next.overrides.firstIndex(where: { $0.id == override.id }) {
            next.overrides[index] = override
        } else {
            next.overrides.append(override)
        }
        commit(next)
    }

    public func deleteOverride(id: String) {
        var next = state
        next.overrides.removeAll { $0.id == id }
        commit(next)
    }

    // MARK: - Memos

    public func upsertMemo(_ note: MemoNote) {
        var next = state
        if let index = next.memos.firstIndex(where: { $0.id == note.id }) {
            next.memos[index] = note
        } else {
            next.memos.append(note)
        }
        commit(next)
    }

    public func deleteMemo(id: String) {
        var next = state
        next.memos.removeAll { $0.id == id }
        commit(next)
    }

    public func toggleMemoChecklist(noteID: String, itemText: String) {
        guard let index = state.memos.firstIndex(where: { $0.id == noteID }) else { return }
        var note = state.memos[index]
        note.body = MemoChecklist.togglingItem(note.body, text: itemText)
        note.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        upsertMemo(note)
    }

    /// Sorted memo list using the shared ordering rules.
    public func sortedMemos(now: Date = .init(), calendar: Calendar = .current) -> [MemoNote] {
        state.memos.sorted(by: memoComparator(now: now, calendar: calendar))
    }

    public func updateTimingProfile(_ profile: TimingProfile) {
        var next = state
        if let index = next.timingProfiles.firstIndex(where: { $0.id == profile.id }) {
            next.timingProfiles[index] = profile
        } else {
            next.timingProfiles.append(profile)
        }
        next.activeTimingProfileID = profile.id
        commit(next)
    }

    public func resetTimingProfile() {
        updateTimingProfile(.defaultProfile())
    }

    /// Reload from disk, for pull-to-refresh and after external edits.
    public func reload() {
        guard let loaded = Self.load(from: storageURL) else { return }
        state = Self.ensuringUsable(loaded, defaultTermName: "")
    }

    // MARK: - Persistence

    private func commit(_ next: AppState) {
        state = next
        save()
    }

    public func save() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: [.atomic])
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func load(from url: URL) -> AppState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            // Keep the unreadable file instead of silently destroying user data.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url
                .deletingPathExtension()
                .appendingPathExtension("corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }

    static func seeded(
        defaultTermName: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AppState {
        let monday = ScheduleCalendar.startOfDisplayWeek(
            containing: now,
            weekStart: .monday,
            calendar: calendar
        )
        let term = Term(
            name: defaultTermName,
            startDate: DateOnly.string(from: monday, calendar: calendar),
            weekCount: defaultTermWeekCount
        )
        let profile = TimingProfile.defaultProfile()
        return AppState(
            terms: [term],
            activeTermID: term.id,
            timingProfiles: [profile],
            activeTimingProfileID: profile.id
        )
    }

    static func ensuringUsable(_ state: AppState, defaultTermName: String) -> AppState {
        var next = state
        next.schemaVersion = AppState.currentSchemaVersion

        if next.terms.isEmpty {
            next.terms = [Term(
                name: defaultTermName,
                startDate: DateOnly.string(from: ScheduleCalendar.startOfDisplayWeek(
                    containing: .now,
                    weekStart: .monday
                )),
                weekCount: defaultTermWeekCount
            )]
        }
        if !next.terms.contains(where: { $0.id == next.activeTermID }) {
            next.activeTermID = next.terms.first?.id ?? ""
        }

        if next.timingProfiles.isEmpty {
            next.timingProfiles = [.defaultProfile()]
        }
        if !next.timingProfiles.contains(where: { $0.id == next.activeTimingProfileID }) {
            next.activeTimingProfileID = next.timingProfiles.first?.id ?? TimingProfile.defaultID
        }
        return next
    }
}
