import CurSimpleCore
import SwiftUI

/// The main week grid: period rows, day columns and course blocks.
struct WeekGridView: View {

    let term: Term
    let profile: TimingProfile
    let preferences: AppPreferences
    let displayWeekStart: Date
    let onTapCourse: (String) -> Void
    let onLongPressCourse: (String) -> Void
    let onTapEmpty: (Int, Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 1

    private var weekNumber: Int? {
        term.weekNumber(on: displayWeekStart, calendar: .current)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            grid
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: max(0, UIScreen.main.bounds.width - 34) / CGFloat(1),
                    alignment: .topLeading
                )
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(value, 0.8), 2.0)
                }
                .onEnded { value in
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = min(max(value, 0.8), 2.0)
                    }
                }
        )
    }

    private var days: [Int] {
        if !preferences.showWeekend {
            return preferences.showSaturday ? Array(1...6) : Array(1...5)
        }
        if preferences.weekStart == .sunday {
            return Array(1...7)
        }
        return Array(1...7)
    }

    private var nodeCount: Int {
        weekGridNodeCount(profile: profile, courses: term.courses)
    }

    private var blocks: [GridCourseBlock] {
        guard let weekNumber, weekNumber >= 1 else { return [] }
        return weekGridBlocks(courses: term.courses, week: weekNumber)
    }

    private var grid: some View {
        let columnWidth: CGFloat = 74
        let rowHeight: CGFloat = 52

        return HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 28)
                ForEach(1...nodeCount, id: \.self) { node in
                    nodeLabel(node)
                        .frame(width: 34, height: rowHeight)
                }
            }

            ForEach(days, id: \.self) { day in
                VStack(spacing: 0) {
                    Text(Format.weekdayNarrow(day))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)

                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(1...nodeCount, id: \.self) { node in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: rowHeight)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onTapEmpty(day, node)
                                    }
                            }
                        }

                        ForEach(blocks.filter { $0.course.time.dayOfWeek == day }) { block in
                            courseBlock(block)
                                .frame(height: CGFloat(block.span) * rowHeight - 4)
                                .padding(.top, CGFloat(block.startNode - 1) * rowHeight + 2)
                                .padding(.horizontal, block.laneCount > 1 ? 1 : 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(width: columnWidth, alignment: .topLeading)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func nodeLabel(_ node: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(node)")
                .font(.caption2.weight(.semibold))
            if let slot = profile.slot(startingAt: node), node == slot.endNode {
                Text(slot.startTime)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.secondary)
    }

    private func courseBlock(_ block: GridCourseBlock) -> some View {
        let course = block.course
        let colors = CoursePalette.colors(for: course, style: preferences.paletteStyle, dark: colorScheme == .dark)
        let slot = profile.slot(coveringNode: course.time.startNode)

        return Button {
            onTapCourse(course.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.text.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !course.location.isEmpty {
                    Text(course.location)
                        .font(.system(size: 10))
                        .foregroundStyle(colors.secondaryText.color)
                        .lineLimit(1)
                }

                if let start = slot?.start, let end = slot?.end {
                    Text("\(start)–\(end)")
                        .font(.system(size: 9))
                        .foregroundStyle(colors.secondaryText.color.opacity(0.8))
                }

                if course.category == .exam {
                    Text("course.examTag")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(colors.accent.color)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colors.fill.color)
            )
            .overlay {
                if course.hidden {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(colors.border.color.opacity(0.55), lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in onLongPressCourse(course.id) }
        )
        .accessibilityLabel("\(course.title), \(course.location)")
    }
}
