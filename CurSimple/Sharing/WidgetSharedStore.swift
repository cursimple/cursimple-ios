import CurSimpleCore
import Foundation

/// App Group file handoff between the app and the home-screen widget.
enum WidgetSharedStore {

    static let appGroupID = "group.com.x500x.cursimple"
    static let fileName = "widget-snapshot.json"

    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    @discardableResult
    static func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = snapshotURL else { return false }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
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
}
