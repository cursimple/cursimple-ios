import Foundation

/// Full local backup: every term, timing profile, preference, memo, holiday and
/// override. Used for device migration and manual safety copies.
public struct BackupPayload: Codable, Sendable {

    public static let currentVersion = 1

    public var v: Int
    public var exportedAtMillis: Int64
    public var appVersion: String
    public var state: AppState

    public init(
        v: Int = BackupPayload.currentVersion,
        exportedAtMillis: Int64,
        appVersion: String,
        state: AppState
    ) {
        self.v = v
        self.exportedAtMillis = exportedAtMillis
        self.appVersion = appVersion
        self.state = state
    }
}

public enum BackupError: Error, Equatable, Sendable {
    case unreadable
    case unsupportedVersion(Int)
    case empty
}

public func makeBackup(
    state: AppState,
    appVersion: String,
    now: Date = .now
) -> BackupPayload {
    BackupPayload(
        exportedAtMillis: Int64(now.timeIntervalSince1970 * 1000),
        appVersion: appVersion,
        state: state
    )
}

public func encodeBackup(_ payload: BackupPayload) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(payload)
}

/// Parse a backup file. Rejects unknown versions instead of guessing.
public func decodeBackup(_ data: Data) throws -> BackupPayload {
    guard let payload = try? JSONDecoder().decode(BackupPayload.self, from: data) else {
        throw BackupError.unreadable
    }
    guard payload.v == BackupPayload.currentVersion else {
        throw BackupError.unsupportedVersion(payload.v)
    }
    guard !payload.state.terms.isEmpty else {
        throw BackupError.empty
    }
    return payload
}

/// Summary shown before the user confirms a restore.
public struct BackupSummary: Sendable, Equatable {
    public let termCount: Int
    public let courseCount: Int
    public let memoCount: Int
    public let overrideCount: Int
    public let holidayEntryCount: Int
    public let exportedAtMillis: Int64
    public let appVersion: String

    public init(
        termCount: Int,
        courseCount: Int,
        memoCount: Int,
        overrideCount: Int,
        holidayEntryCount: Int,
        exportedAtMillis: Int64,
        appVersion: String
    ) {
        self.termCount = termCount
        self.courseCount = courseCount
        self.memoCount = memoCount
        self.overrideCount = overrideCount
        self.holidayEntryCount = holidayEntryCount
        self.exportedAtMillis = exportedAtMillis
        self.appVersion = appVersion
    }
}

public func backupSummary(_ payload: BackupPayload) -> BackupSummary {
    BackupSummary(
        termCount: payload.state.terms.count,
        courseCount: payload.state.terms.reduce(0) { $0 + $1.courses.count },
        memoCount: payload.state.memos.count,
        overrideCount: payload.state.overrides.count,
        holidayEntryCount: payload.state.holidayCalendar.entries.count,
        exportedAtMillis: payload.exportedAtMillis,
        appVersion: payload.appVersion
    )
}

/// Restored state keeps ids so links between memos, overrides and courses survive.
/// The active term falls back to the first one when the stored id is missing.
public func restoredState(from payload: BackupPayload) -> AppState {
    var state = payload.state
    state.schemaVersion = AppState.currentSchemaVersion
    if !state.terms.contains(where: { $0.id == state.activeTermID }) {
        state.activeTermID = state.terms.first?.id ?? ""
    }
    if state.timingProfiles.isEmpty {
        state.timingProfiles = [.defaultProfile()]
    }
    if !state.timingProfiles.contains(where: { $0.id == state.activeTimingProfileID }) {
        state.activeTimingProfileID = state.timingProfiles.first?.id ?? TimingProfile.defaultID
    }
    return state
}

/// Suggested file name: `cursimple-backup-2026-11-07.json`.
public func backupFileName(now: Date = .now, calendar: Calendar = .current) -> String {
    "cursimple-backup-\(DateOnly.string(from: now, calendar: calendar)).json"
}
