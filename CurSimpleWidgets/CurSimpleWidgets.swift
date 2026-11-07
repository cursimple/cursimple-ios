import CurSimpleCore
import SwiftUI
import WidgetKit

@main
struct CurSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        NextWidget()
    }
}

// MARK: - Today

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let day: WidgetDaySnapshot?

    static let placeholder = TodayEntry(
        date: .now,
        snapshot: .preview,
        day: WidgetSnapshot.preview.today
    )
}

struct TodayProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let snapshot = WidgetSharedStore.load()
        let day = snapshot.flatMap { widgetDay($0, selectedMillis: WidgetSharedStore.selectedDayMillis) }
        completion(TodayEntry(date: .now, snapshot: snapshot, day: day))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = WidgetSharedStore.load()
        let day = snapshot.flatMap { widgetDay($0, selectedMillis: WidgetSharedStore.selectedDayMillis) }
        let now = Date()
        var dates: [Date] = [now]

        if let day {
            for course in day.courses {
                for millis in [course.startMillis, course.endMillis].compactMap({ $0 }) {
                    let date = Date(timeIntervalSince1970: Double(millis) / 1000)
                    if date > now, date.timeIntervalSince(now) < 60 * 60 * 24 {
                        dates.append(date)
                    }
                }
            }
        }

        let unique = Array(Set(dates)).sorted().prefix(8).map { $0 }
        let entries = unique.map { TodayEntry(date: $0, snapshot: snapshot, day: day) }
        completion(Timeline(
            entries: entries.isEmpty ? [TodayEntry(date: now, snapshot: snapshot, day: day)] : entries,
            policy: .after(now.addingTimeInterval(30 * 60))
        ))
    }
}

private struct TodayWidgetEntryView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TodayWidgetView(
            snapshot: entry.snapshot,
            day: entry.day,
            date: entry.date,
            family: family
        )
        .containerBackground(for: .widget) {
            WidgetSurface.background(colorScheme)
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CurSimpleToday", provider: TodayProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget.displayNameToday"))
        .description(LocalizedStringKey("widget.descriptionToday"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Next

struct NextEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    static let placeholder = NextEntry(date: .now, snapshot: .preview)
}

struct NextProvider: TimelineProvider {

    func placeholder(in context: Context) -> NextEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NextEntry) -> Void) {
        completion(NextEntry(date: .now, snapshot: WidgetSharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEntry>) -> Void) {
        let snapshot = WidgetSharedStore.load()
        let now = Date()
        var dates: [Date] = [now]
        if let snapshot, let upcoming = widgetUpcomingCourse(snapshot, at: now),
           let start = upcoming.course.startMillis {
            let startDate = Date(timeIntervalSince1970: Double(start) / 1000)
            if startDate > now {
                dates.append(startDate)
            }
        }
        let entries = dates.sorted().map { NextEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

private struct NextWidgetEntryView: View {
    let entry: NextEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NextWidgetView(
            snapshot: entry.snapshot,
            date: entry.date,
            family: family
        )
        .containerBackground(for: .widget) {
            WidgetSurface.background(colorScheme)
        }
    }
}

struct NextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CurSimpleNext", provider: NextProvider()) { entry in
            NextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget.displayNameNext"))
        .description(LocalizedStringKey("widget.descriptionNext"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
