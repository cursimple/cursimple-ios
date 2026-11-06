import CurSimpleCore
import SwiftUI
import Combine

/// Single-day view with a today overview on top and the full timeline below.
struct DayView: View {

    let term: Term
    let profile: TimingProfile
    let date: Date
    let onOpenCourse: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var now: Date = .now

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let items = occurrences(on: date, term: term, profile: profile, calendar: .current)

        ScrollView {
            VStack(spacing: AppMetrics.pagePadding) {
                if Calendar.current.isDateInToday(date) {
                    TodayOverview(items: items, now: now)
                        .onReceive(timer) { now = $0 }
                }

                if items.isEmpty {
                    EmptyStateView(
                        systemImage: "cup.and.saucer",
                        title: "day.empty.title",
                        message: "day.empty.message"
                    )
                } else {
                    timeline(items)
                }
            }
            .padding(AppMetrics.pagePadding)
        }
    }

    private func timeline(_ items: [ScheduledCourseOccurrence]) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                TimelineCard(item: item) {
                    onOpenCourse(item.course.id)
                }
            }
        }
    }
}

// MARK: - Today overview

private struct TodayOverview: View {

    let items: [ScheduledCourseOccurrence]
    let now: Date

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("today.title")
                    .font(.headline)
                Spacer()
                if !timed.isEmpty {
                    Text(String(format: String(localized: "today.completed"), completedCount, timed.count))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let current {
                HStack {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.title)
                            .font(.subheadline.weight(.semibold))
                        Text(String(
                            format: String(localized: "today.endsIn"),
                            Format.remaining(until: current.end!, from: now)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let next {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("today.next")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(next.title)
                                .font(.caption.weight(.semibold))
                            Text(Format.remaining(until: next.start!, from: now))
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.09))
                )
            } else if let next {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("today.freeNow")
                            .font(.subheadline.weight(.semibold))
                        Text(String(
                            format: String(localized: "today.nextStartsIn"),
                            next.title,
                            Format.remaining(until: next.start!, from: now)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else if timed.isEmpty {
                Text("today.allClear")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("today.doneForToday")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppMetrics.cardPadding)
        .appCard(colorScheme: colorScheme)
    }

    private var timed: [ScheduledCourseOccurrence] {
        items.filter(\.hasTime)
    }

    private var completedCount: Int {
        timed.filter { $0.end! <= now }.count
    }

    private var current: ScheduledCourseOccurrence? {
        timed.first { $0.start! <= now && $0.end! > now }
    }

    private var next: ScheduledCourseOccurrence? {
        timed.first { $0.start! > now }
    }
}

// MARK: - Timeline card

private struct TimelineCard: View {

    let item: ScheduledCourseOccurrence
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    if let start = item.start, let end = item.end {
                        Text(TimeOfDay(date: start).text)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                        Text(TimeOfDay(date: end).text)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Format.periodRange(item.course.time.startNode, item.course.time.endNode))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if item.course.category == .exam {
                            Text("course.examTag")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.red)
                        }
                    }
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !item.teacher.isEmpty {
                        Label(item.teacher, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppMetrics.cardPadding)
            .appCard(colorScheme: colorScheme)
        }
        .buttonStyle(.plain)
    }
}
