import Combine
import CurSimpleCore
import SwiftUI

/// Day timetable with an overview card for today.
struct DayView: View {

    let term: Term
    let profile: TimingProfile
    let date: Date
    let onOpenCourse: (String) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var now: Date = .now

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let items = occurrences(on: date, term: term, profile: profile, calendar: .current)

        VStack(spacing: 0) {
            dayHeader(colors: colors)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if Calendar.current.isDateInToday(date) {
                        TodayOverview(items: items, now: now, colors: colors)
                            .onReceive(timer) { now = $0 }
                    }

                    if items.isEmpty {
                        emptyState(colors: colors)
                    } else {
                        ForEach(items) { item in
                            timelineCard(item, colors: colors)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .padding(.bottom, 28)
            }
        }
    }

    private func dayHeader(colors: AppColors) -> some View {
        HStack(spacing: 10) {
            Text(date.formatted(.dateTime.month().day()))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.todayOnContainer)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.todayContainer)
                )

            Text(Format.weekday(ScheduleCalendar.isoDayOfWeek(date)))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(colors.onSurfaceVariant)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func timelineCard(_ item: ScheduledCourseOccurrence, colors: AppColors) -> some View {
        let entry = CoursePalette.courseEntry(
            for: item.course,
            style: store.preferences.paletteStyle,
            dark: colorScheme == .dark
        )
        let periodLabel = Format.periodRange(
            item.course.time.startNode,
            item.course.time.endNode
        )

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Format.period(item.course.time.startNode))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(colors.onSurface)

                if let start = item.start, let end = item.end {
                    Text(TimeOfDay(date: start).text)
                        .font(.system(size: 9))
                        .foregroundStyle(colors.onSurfaceVariant)
                    Text(TimeOfDay(date: end).text)
                        .font(.system(size: 9))
                        .foregroundStyle(colors.onSurfaceVariant)
                }
            }
            .frame(width: 52, alignment: .leading)
            .padding(.top, 6)

            Button {
                onOpenCourse(item.course.id)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(entry.onContainer.color)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        Text(periodLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(entry.onContainer.color.opacity(0.62))
                    }

                    if !item.location.isEmpty {
                        Text("@\(item.location)")
                            .font(.system(size: 12))
                            .foregroundStyle(entry.onContainer.color.opacity(0.78))
                    }

                    if !item.teacher.isEmpty {
                        Text(item.teacher)
                            .font(.system(size: 12))
                            .foregroundStyle(entry.onContainer.color.opacity(0.78))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(entry.container.color)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func emptyState(colors: AppColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 24))
                .foregroundStyle(colors.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(colors.primaryContainer))

            Text("day.empty.title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
            Text("day.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Today overview

private struct TodayOverview: View {

    let items: [ScheduledCourseOccurrence]
    let now: Date
    let colors: AppColors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("today.title")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !timed.isEmpty {
                    Text(String(format: String(localized: "today.completed"), completedCount, timed.count))
                        .font(AppFont.label)
                        .opacity(0.72)
                }
            }

            if let current {
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(
                        format: String(localized: "today.endsIn"),
                        Format.remaining(until: current.end!, from: now)
                    ))
                    .font(AppFont.bodySmall)
                    .opacity(0.78)
                }
            } else if let next {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(
                        format: String(localized: "today.nextStartsIn"),
                        next.title,
                        Format.remaining(until: next.start!, from: now)
                    ))
                    .font(.system(size: 14, weight: .medium))
                }
            } else if timed.isEmpty {
                Text("today.allClear")
                    .font(AppFont.bodySmall)
                    .opacity(0.78)
            } else {
                Text("today.doneForToday")
                    .font(AppFont.bodySmall)
                    .opacity(0.78)
            }
        }
        .foregroundStyle(colors.onPrimaryContainer)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.primaryContainer)
        )
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
