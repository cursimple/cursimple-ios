import CurSimpleCore
import Foundation

/// App Group file handoff between the app and the home-screen widgets.
enum WidgetSharedStore {

    static let appGroupID = "group.com.x500x.cursimple"
    static let fileName = "widget-snapshot.json"
    static let selectedDayKey = "widget.selectedDayMillis"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static var selectedDayMillis: Int64? {
        get { (defaults?.object(forKey: selectedDayKey) as? NSNumber)?.int64Value }
        set {
            if let newValue {
                defaults?.set(NSNumber(value: newValue), forKey: selectedDayKey)
            } else {
                defaults?.removeObject(forKey: selectedDayKey)
            }
        }
    }

    @discardableResult
    static func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = snapshotURL else { return false }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            // A day outside the new window (or a new day) falls back to today.
            if let selected = selectedDayMillis,
               !snapshot.days.contains(where: { $0.dayMillis == selected }) {
                selectedDayMillis = nil
            }
            return true
        } catch {
            return false
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Move the widget's selected day by `delta`, clamped to the snapshot window.
    @discardableResult
    static func shiftSelectedDay(by delta: Int, calendar: Calendar = .current) -> Int64? {
        guard let snapshot = load(),
              let current = widgetDay(snapshot, selectedMillis: selectedDayMillis) else {
            return nil
        }
        let date = Date(timeIntervalSince1970: Double(current.dayMillis) / 1000)
        let target = ScheduleCalendar.addDays(delta, to: date, calendar: calendar)
        let targetMillis = Int64(calendar.startOfDay(for: target).timeIntervalSince1970 * 1000)
        guard snapshot.days.contains(where: { $0.dayMillis == targetMillis }) else {
            return current.dayMillis
        }
        selectedDayMillis = targetMillis
        return targetMillis
    }
}
