import Combine
import CurSimpleCore
import SwiftUI

/// Day timetable with the full today overview card, matching the shared design.
struct DayView: View {

    let term: Term
    let profile: TimingProfile
    let date: Date
    let onOpenCourse: (String) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var now: Date = DayView.debugNow()
    @State private var clockFrozen = ProcessInfo.processInfo.arguments.contains("-todayNow")

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// QA hook: `-todayNow "HH:mm"` freezes the overview clock at that time.
    private static func debugNow() -> Date {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-todayNow"),
              arguments.count > index + 1,
              let time = TimeOfDay(arguments[index + 1]) else {
            return .now
        }
        return time.date(on: .now) ?? .now
    }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let items = occurrences(on: date, term: term, profile: profile, calendar: .current)

        VStack(spacing: 0) {
            dayHeader(colors: colors)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if Calendar.current.isDateInToday(date) {
                        TodayOverviewCard(items: items, now: now, colors: colors)
                            .onReceive(timer) { value in
                                if !clockFrozen {
                                    now = value
                                }
                            }
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

                        Text(Format.periodRange(item.course.time.startNode, item.course.time.endNode))
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

// MARK: - Today state

private struct TodayState {
    let timed: [ScheduledCourseOccurrence]
    let current: ScheduledCourseOccurrence?
    let next: ScheduledCourseOccurrence?
    let doneCount: Int
    let unknownTimeCount: Int
    let nowValue: Date?

    init(items: [ScheduledCourseOccurrence], now: Date) {
        timed = items.filter(\.hasTime)
        current = timed.first { $0.start! <= now && $0.end! > now }
        next = timed.first { $0.start! > now }
        doneCount = timed.filter { $0.end! <= now }.count
        unknownTimeCount = items.filter { !$0.hasTime }.count
        nowValue = now
    }

    var total: Int { timed.count }

    /// 0...1 progress through the current class.
    var currentProgress: Double {
        guard let current, let now = nowValue else { return 0 }
        let total = current.end!.timeIntervalSince(current.start!)
        guard total > 0 else { return 0 }
        return min(max(now.timeIntervalSince(current.start!) / total, 0), 1)
    }

    var statusTitleKey: LocalizedStringKey {
        if current != nil { return "today.status.current" }
        if next != nil { return "today.status.next" }
        if unknownTimeCount > 0 { return "today.status.needTiming" }
        if total == 0 { return "today.status.empty" }
        return "today.status.finished"
    }

    var countdownText: String? {
        if let current, let now = nowValue {
            let seconds = Int(ceil(current.end!.timeIntervalSince(now)))
            if seconds < 3600 {
                return String(
                    format: String(localized: "today.secondsToEnd"),
                    seconds / 60,
                    seconds % 60
                )
            }
            return String(format: String(localized: "today.minutesToEnd"), Int(ceil(Double(seconds) / 60)))
        }
        if let next, let now = nowValue {
            let seconds = Int(ceil(next.start!.timeIntervalSince(now)))
            if seconds < 3600 {
                return String(
                    format: String(localized: "today.secondsToStart"),
                    seconds / 60,
                    seconds % 60
                )
            }
            let minutes = Int(ceil(Double(seconds) / 60))
            if minutes < 60 {
                return String(format: String(localized: "today.minutesToEnd"), minutes)
            }
            return String(
                format: String(localized: "today.hoursToStart"),
                minutes / 60,
                minutes % 60
            )
        }
        return nil
    }
}

// MARK: - Overview card

private struct TodayOverviewCard: View {

    let items: [ScheduledCourseOccurrence]
    let now: Date
    let colors: AppColors

    @State private var appeared = false

    private var state: TodayState {
        TodayState(items: items, now: now)
    }

    var body: some View {
        let state = state
        let active = state.current != nil
        let container = active ? colors.primaryContainer : colors.surfaceVariant
        let content = active ? colors.onPrimaryContainer : colors.onSurface
        let muted = content.opacity(0.72)
        let focus = state.current ?? state.next

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                progressRing(state, content: content)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.statusTitleKey)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.primary)

                    if let focus {
                        Text(focus.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(content)
                            .lineLimit(1)

                        Text(occurrenceInfo(focus))
                            .font(AppFont.bodySmall)
                            .foregroundStyle(muted)
                            .lineLimit(1)
                    } else {
                        Text(String(
                            format: String(localized: "today.count"),
                            state.total,
                            max(state.total - state.doneCount, 0)
                        ))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(content)
                    }
                }

                Spacer(minLength: 0)
            }

            if let current = state.current {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(content.opacity(0.12))
                        Capsule()
                            .fill(colors.primary)
                            .frame(width: max(proxy.size.width * currentProgress(animated: appeared, value: state.currentProgress), 8))
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: 8) {
                if let countdown = state.countdownText {
                    chip(countdown, fill: colors.primary.opacity(0.14), text: colors.primary)
                }
                if let next = state.next, state.current != nil {
                    Text(String(
                        format: String(localized: "today.nextBrief"),
                        next.title,
                        TimeOfDay(date: next.start!).text
                    ))
                    .font(AppFont.bodySmall)
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(container)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private func currentProgress(animated: Bool, value: Double) -> Double {
        animated ? value : 0
    }

    // MARK: Progress ring

    private func progressRing(_ state: TodayState, content: Color) -> some View {
        let total = max(state.total, 1)
        let fraction = Double(state.doneCount) / Double(total)
        let animatedFraction = appeared ? fraction : 0

        return ZStack {
            Circle()
                .stroke(content.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(colors.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            HStack(alignment: .bottom, spacing: 0) {
                Text("\(state.doneCount)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(content)
                Text("/\(total)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(content.opacity(0.7))
                    .padding(.bottom, 2)
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityLabel(String(
            format: String(localized: "today.progressDesc"),
            state.doneCount,
            total
        ))
    }

    private func chip(_ text: String, fill: Color, text color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }

    private func occurrenceInfo(_ item: ScheduledCourseOccurrence) -> String {
        var parts: [String] = []
        if let start = item.start, let end = item.end {
            parts.append("\(TimeOfDay(date: start).text)–\(TimeOfDay(date: end).text)")
        } else {
            parts.append(String(localized: "today.timeMissing"))
        }
        if !item.location.isEmpty { parts.append(item.location) }
        if !item.teacher.isEmpty { parts.append(item.teacher) }
        return parts.joined(separator: " · ")
    }
}
