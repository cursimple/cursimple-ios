import CurSimpleCore
import SwiftUI
import WidgetKit

@main
struct CurSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    static let placeholder = TodayEntry(date: .now, snapshot: .preview)
}

struct TodayProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: WidgetSharedStore.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = WidgetSharedStore.load()
        let now = Date()
        var dates: [Date] = [now]

        // Entries at each class boundary keep the current/next state accurate
        // without relying on frequent refreshes.
        if let snapshot {
            for course in snapshot.courses {
                for millis in [course.startMillis, course.endMillis].compactMap({ $0 }) {
                    let date = Date(timeIntervalSince1970: Double(millis) / 1000)
                    if date > now, date.timeIntervalSince(now) < 60 * 60 * 20 {
                        dates.append(date)
                    }
                }
            }
        }

        let unique = Array(Set(dates)).sorted().prefix(8).map { $0 }
        let entries = unique.map { TodayEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(
            entries: entries.isEmpty ? [TodayEntry(date: now, snapshot: snapshot)] : entries,
            policy: .after(now.addingTimeInterval(30 * 60))
        ))
    }
}

// MARK: - Widget

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CurSimpleToday", provider: TodayProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget.displayName"))
        .description(LocalizedStringKey("widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct TodayWidgetEntryView: View {

    let entry: TodayEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        TodayWidgetView(snapshot: entry.snapshot, date: entry.date, family: family)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
    }
}
