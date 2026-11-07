import CurSimpleCore
import SwiftUI
import WidgetKit

/// Shared by the widget extension and the in-app debug preview.
struct TodayWidgetView: View {

    let snapshot: WidgetSnapshot?
    let date: Date
    let family: WidgetFamily

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .padding(14)
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(showWeek: false)

            if let snapshot, snapshot.isHoliday {
                Spacer(minLength: 0)
                Text(snapshot.holiday ?? String(localized: "widget.holiday"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(primary)
                Text("widget.rest")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if let current = currentCourse {
                Text("widget.inClass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primary)
                Text(current.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                Text("\(current.startText)–\(current.endText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                progressBar(course: current)
                    .padding(.top, 2)
            } else if let next = nextCourse {
                Text("widget.next")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primary)
                Text(next.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                Text("\(next.startText)–\(next.endText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if !next.location.isEmpty {
                    Text("@\(next.location)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                Text("widget.empty")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header()

            if let snapshot {
                if snapshot.isHoliday {
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Image(systemName: "tree.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(primary)
                        Text(snapshot.holiday ?? String(localized: "widget.holiday"))
                            .font(.system(size: 14, weight: .semibold))
                        Text("widget.rest")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                } else if snapshot.courses.isEmpty {
                    Spacer(minLength: 0)
                    Text("widget.empty")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    VStack(spacing: 5) {
                        ForEach(snapshot.courses.prefix(4)) { course in
                            courseRow(course)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 0)
                Text("widget.noData")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces

    private func header(showWeek: Bool = true) -> some View {
        HStack(spacing: 6) {
            Text("widget.today")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            if showWeek, let snapshot, snapshot.weekNumber >= 1 {
                Text(String(format: String(localized: "widget.week"), snapshot.weekNumber))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(primary.opacity(0.14)))
            }
            Spacer()
            Text(date.formatted(.dateTime.month().day()))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if let snapshot {
                Text(snapshot.termName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            if let snapshot, !snapshot.courses.isEmpty {
                Text(String(format: String(localized: "widget.courseCount"), snapshot.courses.count))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func courseRow(_ course: WidgetCourseEntry) -> some View {
        let colors = courseColors(course)
        let isCurrent = currentCourse?.id == course.id

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(colors.accent)
                .frame(width: 3)

            Text(course.startText)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)

            Text(course.title)
                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                .lineLimit(1)

            Spacer(minLength: 0)

            if !course.location.isEmpty {
                Text(course.location)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? colors.fill.opacity(0.8) : .clear)
        )
    }

    private func progressBar(course: WidgetCourseEntry) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(primary.opacity(0.14))
                Capsule()
                    .fill(primary)
                    .frame(width: max(proxy.size.width * widgetProgress(course, at: date), 4))
            }
        }
        .frame(height: 4)
    }

    // MARK: Derived

    private var currentCourse: WidgetCourseEntry? {
        snapshot.flatMap { widgetCurrentCourse($0, at: date) }
    }

    private var nextCourse: WidgetCourseEntry? {
        snapshot.flatMap { widgetNextCourse($0, at: date) }
    }

    private var primary: Color {
        widgetColor(RGBColor(hex: "#3FA277")!)
    }

    private func courseColors(_ course: WidgetCourseEntry) -> (fill: Color, accent: Color) {
        if let argb = course.colorArgb {
            let color = widgetColor(RGBColor(argb: argb))
            return (color.opacity(0.55), color)
        }
        let style = CoursePaletteStyle(rawValue: snapshot?.paletteStyle ?? "default") ?? .standard
        let palette = CoursePalette.entries(for: style, dark: colorScheme == .dark)
        guard !palette.isEmpty else { return (primary.opacity(0.2), primary) }
        let index = CoursePalette.paletteIndex(forSeed: course.title, count: palette.count)
        return (widgetColor(palette[index].container), widgetColor(palette[index].onContainer))
    }
}

func widgetColor(_ color: RGBColor) -> Color {
    Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
}

extension WidgetSnapshot {
    static let preview = WidgetSnapshot(
        generatedAtMillis: Int64(Date().timeIntervalSince1970 * 1000),
        termName: "2026-2027 第1学期",
        weekNumber: 2,
        dayMillis: Int64(Calendar.current.startOfDay(for: .now).timeIntervalSince1970 * 1000),
        holidayName: nil,
        paletteStyle: CoursePaletteStyle.standard.rawValue,
        courses: [
            WidgetCourseEntry(
                id: "p1", title: "高等数学", location: "博文楼-B305", teacher: "张老师",
                startMillis: Int64(Date().timeIntervalSince1970 * 1000) + 15 * 60 * 1000,
                endMillis: Int64(Date().timeIntervalSince1970 * 1000) + 105 * 60 * 1000,
                startText: "08:00", endText: "09:40", colorArgb: nil, isExam: false
            ),
            WidgetCourseEntry(
                id: "p2", title: "大学英语", location: "博文楼-B305", teacher: "",
                startMillis: Int64(Date().timeIntervalSince1970 * 1000) + 120 * 60 * 1000,
                endMillis: Int64(Date().timeIntervalSince1970 * 1000) + 210 * 60 * 1000,
                startText: "10:00", endText: "11:40", colorArgb: nil, isExam: false
            ),
            WidgetCourseEntry(
                id: "p3", title: "大学物理实验", location: "格物楼-D210", teacher: "",
                startMillis: Int64(Date().timeIntervalSince1970 * 1000) + 240 * 60 * 1000,
                endMillis: Int64(Date().timeIntervalSince1970 * 1000) + 330 * 60 * 1000,
                startText: "14:00", endText: "15:40", colorArgb: nil, isExam: false
            ),
        ]
    )
}
