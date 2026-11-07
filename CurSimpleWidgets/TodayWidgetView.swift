import AppIntents
import CurSimpleCore
import SwiftUI
import WidgetKit

// MARK: - Day navigation

struct ShiftWidgetDayIntent: AppIntent {

    static let title: LocalizedStringResource = "widget.shiftDay"

    @Parameter(title: "Delta")
    var delta: Int

    init() {}

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        WidgetSharedStore.shiftSelectedDay(by: delta)
        WidgetCenter.shared.reloadTimelines(ofKind: "CurSimpleToday")
        return .result()
    }
}

// MARK: - Today widget

/// Shared by the widget extension and the in-app debug preview.
struct TodayWidgetView: View {

    let snapshot: WidgetSnapshot?
    let day: WidgetDaySnapshot?
    let date: Date
    let family: WidgetFamily

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let day, day.isHoliday {
                centered {
                    Text(day.holiday ?? String(localized: "widget.holiday"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("widget.rest")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let day, day.courses.isEmpty {
                centered {
                    Text("widget.empty")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if let day {
                VStack(spacing: 8) {
                    ForEach(day.courses.prefix(cardLimit)) { course in
                        courseCard(course)
                    }
                }
                if family == .systemLarge, day.courses.count > cardLimit {
                    Text(String(format: String(localized: "widget.moreCourses"), day.courses.count - cardLimit))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                centered {
                    Text("widget.noData")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var cardLimit: Int {
        switch family {
        case .systemSmall: 1
        case .systemLarge: 5
        default: 1
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if family != .systemSmall {
                navButton(systemImage: "chevron.left", delta: -1)
            } else {
                Spacer().frame(width: 2)
            }

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(headerTitle)
                    .font(.system(size: family == .systemSmall ? 16 : 19, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if family != .systemSmall {
                    Text(weekdayText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if family != .systemSmall {
                navButton(systemImage: "chevron.right", delta: 1)
            }
        }
    }

    private func navButton(systemImage: String, delta: Int) -> some View {
        Button(intent: ShiftWidgetDayIntent(delta: delta)) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.72))
                .frame(width: 30, height: 30)
                .background(Circle().fill(navFill))
        }
        .buttonStyle(.plain)
    }

    private var headerTitle: String {
        let dayDate = day.map { Date(timeIntervalSince1970: Double($0.dayMillis) / 1000) } ?? date
        let base = dayDate.formatted(.dateTime.month().day())
        guard let snapshot, let day, day.dayMillis == snapshot.todayMillis else {
            return base
        }
        return "\(base) · \(String(localized: "widget.todayLabel"))"
    }

    private var weekdayText: String {
        let dayDate = day.map { Date(timeIntervalSince1970: Double($0.dayMillis) / 1000) } ?? date
        return dayDate.formatted(.dateTime.weekday(.abbreviated))
    }

    private func courseCard(_ course: WidgetCourseEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(periodLabel(course))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(course.startText)–\(course.endText)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Text(course.title)
                .font(.system(size: family == .systemSmall ? 16 : 18, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if !course.location.isEmpty, family != .systemSmall {
                Text(course.location)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill)
        )
    }

    private func centered<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func periodLabel(_ course: WidgetCourseEntry) -> String {
        if course.startNode == course.endNode {
            return String(format: String(localized: "widget.periodSingle"), course.startNode)
        }
        return String(format: String(localized: "widget.periodRange"), course.startNode, course.endNode)
    }

    // Widget palette matches the shared green surfaces rather than per-course colors.
    private var widgetBackground: Color {
        widgetColor(RGBColor(hex: colorScheme == .dark ? "#1B241E" : "#E7F2E4")!)
    }

    private var cardFill: Color {
        widgetColor(RGBColor(hex: colorScheme == .dark ? "#2C3B31" : "#CFE8CC")!)
    }

    private var navFill: Color {
        widgetColor(RGBColor(hex: colorScheme == .dark ? "#34473A" : "#C3E1BF")!)
    }

    var backgroundFill: Color { widgetBackground }
}

// MARK: - Next widget

struct NextWidgetView: View {

    let snapshot: WidgetSnapshot?
    let date: Date
    let family: WidgetFamily

    @Environment(\.colorScheme) private var colorScheme

    private var upcoming: (day: WidgetDaySnapshot, course: WidgetCourseEntry)? {
        snapshot.flatMap { widgetUpcomingCourse($0, at: date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("widget.nextTitle")
                    .font(.system(size: family == .systemSmall ? 16 : 22, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 4)

                if let upcoming {
                    Text(countdownText(upcoming.course, compact: family == .systemSmall))
                        .font(.system(size: family == .systemSmall ? 10 : 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(widgetColor(RGBColor(hex: "#2C5587")!))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(widgetColor(RGBColor(hex: "#D6E4F7")!)))
                }
            }

            if let upcoming {
                VStack(alignment: .leading, spacing: 3) {
                    Text(upcoming.course.title)
                        .font(.system(size: family == .systemSmall ? 16 : 19, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        Text("\(upcoming.course.startText)–\(upcoming.course.endText)")
                        if !upcoming.course.location.isEmpty, family != .systemSmall {
                            Text("·")
                            Text(upcoming.course.location)
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: family == .systemSmall ? 11 : 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(widgetColor(RGBColor(hex: colorScheme == .dark ? "#2C3B31" : "#CFE8CC")!))
                )
            } else {
                Text("widget.noMore")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func countdownText(_ course: WidgetCourseEntry, compact: Bool) -> String {
        guard let start = course.startMillis else { return course.startText }
        let seconds = max(0, Double(start) / 1000 - date.timeIntervalSince1970)
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes <= 1 { return String(localized: "widget.startingNow") }
        if minutes < 60 {
            return String(
                format: String(localized: compact ? "widget.inMinutesShort" : "widget.inMinutes"),
                minutes
            )
        }
        let hours = Int((Double(minutes) / 60).rounded(.up))
        return String(
            format: String(localized: compact ? "widget.inHoursShort" : "widget.inHours"),
            hours
        )
    }

    var backgroundFill: Color {
        widgetColor(RGBColor(hex: colorScheme == .dark ? "#1B241E" : "#E7F2E4")!)
    }
}

// MARK: - Helpers

func widgetColor(_ color: RGBColor) -> Color {
    Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
}

enum WidgetSurface {
    static func background(_ scheme: ColorScheme) -> Color {
        widgetColor(RGBColor(hex: scheme == .dark ? "#1B241E" : "#E7F2E4")!)
    }
}

extension WidgetSnapshot {
    static let preview: WidgetSnapshot = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let todayMillis = Int64(today.timeIntervalSince1970 * 1000)
        func entry(_ id: String, _ title: String, _ location: String, hour: Int, minute: Int, duration: Int) -> WidgetCourseEntry {
            let start = calendar.date(byAdding: .minute, value: hour * 60 + minute, to: today) ?? today
            let end = start.addingTimeInterval(TimeInterval(duration * 60))
            return WidgetCourseEntry(
                id: id,
                title: title,
                location: location,
                teacher: "",
                startMillis: Int64(start.timeIntervalSince1970 * 1000),
                endMillis: Int64(end.timeIntervalSince1970 * 1000),
                startText: String(format: "%02d:%02d", hour, minute),
                endText: String(format: "%02d:%02d", (hour * 60 + minute + duration) / 60, (hour * 60 + minute + duration) % 60),
                startNode: hour == 8 ? 1 : (hour == 10 ? 3 : 5),
                endNode: hour == 8 ? 2 : (hour == 10 ? 4 : 6),
                colorArgb: nil,
                isExam: false
            )
        }
        let todayDay = WidgetDaySnapshot(
            dayMillis: todayMillis,
            weekNumber: 2,
            holidayName: nil,
            courses: [
                entry("p1", "算法与数据结构", "博文楼-B305", hour: 8, minute: 0, duration: 95),
                entry("p2", "毛泽东思想概论", "博文楼-B305", hour: 10, minute: 5, duration: 95),
                entry("p3", "大学物理实验", "格物楼-D210", hour: 14, minute: 0, duration: 100),
            ]
        )
        let tomorrow = WidgetDaySnapshot(
            dayMillis: todayMillis + 86_400_000,
            weekNumber: 2,
            holidayName: nil,
            courses: [entry("p4", "高等数学", "教学楼-A201", hour: 8, minute: 0, duration: 95)]
        )
        return WidgetSnapshot(
            generatedAtMillis: Int64(Date().timeIntervalSince1970 * 1000),
            termName: "2026-2027 第1学期",
            paletteStyle: CoursePaletteStyle.standard.rawValue,
            todayMillis: todayMillis,
            days: [todayDay, tomorrow]
        )
    }()
}
