import CurSimpleCore
import SwiftUI

struct CourseEditorTarget: Identifiable {
    let id = UUID()
    let course: CourseItem?
    let slot: CourseTimeSlot
    /// Category preselected when creating a new entry.
    var presetCategory: CourseCategory = .course
}

struct ScheduleView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var displayWeekStart: Date = ScheduleView.initialDisplayWeekStart()
    @State private var viewMode: ScheduleViewMode = ProcessInfo.processInfo.arguments.contains("-startDayView") ? .day : .week
    @State private var selectedDay: Date = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-dayOffset"),
              arguments.count > index + 1,
              let offset = Int(arguments[index + 1]) else {
            return .now
        }
        return ScheduleCalendar.addDays(offset, to: .now)
    }()
    @State private var editorTarget: CourseEditorTarget? = ProcessInfo.processInfo.arguments.contains("-openEditor")
        ? CourseEditorTarget(course: nil, slot: CourseTimeSlot(dayOfWeek: 1, startNode: 1, endNode: 2))
        : nil
    @State private var detailCourseID: String? = ProcessInfo.processInfo.arguments.contains("-openCourseDetail")
        ? ProcessInfo.processInfo.environment["COURSE_ID"]
        : nil
    @State private var showTermPicker = false
    @State private var showWeekPicker = ProcessInfo.processInfo.arguments.contains("-openWeekPicker")

    /// QA hook: `-weekOffset N` opens N weeks from the current one.
    private static func initialDisplayWeekStart() -> Date {
        let base = ScheduleCalendar.startOfDisplayWeek(containing: .now, weekStart: .monday)
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-weekOffset"),
              arguments.count > index + 1,
              let offset = Int(arguments[index + 1]) else {
            return base
        }
        return ScheduleCalendar.addWeeks(offset, to: base)
    }

    private var preferences: AppPreferences { store.preferences }
    private var term: Term? { store.activeTerm }

    var body: some View {
        let colors = AppColors.resolve(accent: preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(colors: colors)
                contentCard(colors: colors)
            }
        }
        .tint(colors.primary)
        .sheet(item: $editorTarget) { target in
            CourseEditorView(editing: target.course, initialSlot: target.slot) { result in
                commit(result, target: target)
            }
            .presentationDetents([.large])
        }
        .sheet(item: Binding(
            get: {
                let id = detailCourseID ?? (ProcessInfo.processInfo.arguments.contains("-openCourseDetail")
                    ? store.activeTerm?.courses.first?.id
                    : nil)
                return id.flatMap { id in
                    store.activeTerm?.courses.first { $0.id == id }
                }
            },
            set: { detailCourseID = $0?.id }
        )) { course in
            CourseDetailView(course: course, term: term) { updated in
                store.updateCourse(updated)
            } onDelete: {
                store.deleteCourse(id: course.id)
                detailCourseID = nil
            } onHide: {
                var copy = course
                copy.hidden = true
                store.updateCourse(copy)
                detailCourseID = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTermPicker) {
            TermPickerView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWeekPicker) {
            if let term {
                WeekPickerSheet(
                    term: term,
                    currentWeekStart: displayWeekStart,
                    weekStartDay: preferences.weekStart
                ) { start in
                    withAnimation(.easeOut(duration: 0.2)) {
                        displayWeekStart = start
                    }
                }
            }
        }
        .onChange(of: term?.id) { _, _ in
            displayWeekStart = ScheduleCalendar.startOfDisplayWeek(
                containing: .now,
                weekStart: preferences.weekStart
            )
        }
    }

    // MARK: - Top bar

    private func topBar(colors: AppColors) -> some View {
        ZStack {
            HStack {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .appFont(21, weight: .medium)
                        .foregroundStyle(colors.onBackground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("drawer.open")

                Spacer()

                HStack(spacing: 8) {
                    viewModeButton(colors: colors)
                    addButton(colors: colors)
                }
            }

            VStack(spacing: 2) {
                weekPill(colors: colors)
                Text(term?.name ?? String(localized: "schedule.title"))
                    .font(AppFont.label)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .padding(.horizontal, 74)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private func weekPill(colors: AppColors) -> some View {
        let displayed = displayedWeekNumber
        let current = currentWeekNumber
        let isCurrent = displayed != nil && displayed == current

        return Button {
            showWeekPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(weekLabelText)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(isCurrent ? colors.onPrimaryContainer : colors.onSurface)

                if isCurrent {
                    Text("week.thisWeek")
                        .appFont(10, weight: .semibold)
                        .foregroundStyle(colors.onPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(colors.primary))
                }

                Image(systemName: "chevron.down")
                    .appFont(10, weight: .bold)
                    .foregroundStyle(isCurrent ? colors.onPrimaryContainer : colors.onSurfaceVariant)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isCurrent ? colors.primaryContainer : colors.surfaceVariant.opacity(0.55))
            )
            .overlay(
                Capsule().stroke(
                    isCurrent ? colors.primary.opacity(0.25) : colors.outlineVariant.opacity(0.45),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(weekAccessibilityLabel))
    }

    /// VoiceOver must hear the current week, not just the action name.
    private var weekAccessibilityLabel: String {
        let week = weekLabelText
        let hint = String(localized: "schedule.switchWeek")
        return "\(week)，\(hint)"
    }

    private func viewModeButton(colors: AppColors) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if viewMode == .week {
                    selectedDay = .now
                    viewMode = .day
                } else {
                    viewMode = .week
                }
            }
        } label: {
            Text(viewMode == .week ? "schedule.weekShort" : "schedule.dayShort")
                .appFont(13, weight: .semibold)
                .foregroundStyle(colors.onSurface)
                .frame(width: 40, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(colors.outlineVariant, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewMode == .week ? "schedule.showDay" : "schedule.showWeek")
    }

    private func addButton(colors: AppColors) -> some View {
        Button {
            editorTarget = CourseEditorTarget(
                course: nil,
                slot: CourseTimeSlot(dayOfWeek: defaultDay, startNode: 1, endNode: 2)
            )
        } label: {
            Image(systemName: "plus")
                .appFont(18, weight: .medium)
                .foregroundStyle(colors.onSurface)
                .frame(width: 40, height: 40)
                .background(Circle().fill(colors.surface))
                .overlay(Circle().stroke(colors.outlineVariant, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("schedule.addCourse")
    }

    private var defaultDay: Int {
        if viewMode == .day {
            return ScheduleCalendar.isoDayOfWeek(selectedDay)
        }
        return 1
    }

    // MARK: - Content card

    private func contentCard(colors: AppColors) -> some View {
        Group {
            if let term {
                if viewMode == .week {
                    WeekGridView(
                        term: term,
                        profile: store.timingProfile,
                        preferences: preferences,
                        displayWeekStart: displayWeekStart,
                        onTapCourse: { detailCourseID = $0 },
                        onLongPressCourse: { id in
                            guard let course = term.courses.first(where: { $0.id == id }) else { return }
                            editorTarget = CourseEditorTarget(course: course, slot: course.time)
                        },
                        onTapEmpty: { slot in
                            editorTarget = CourseEditorTarget(course: nil, slot: slot)
                        },
                        onSelectDay: { date in
                            selectedDay = date
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = .day
                            }
                        },
                        onMoveCourse: { course, day, startNode in
                            moveCourse(course, toDay: day, startNode: startNode, term: term)
                        }
                    )
                    .overlay {
                        if term.courses.isEmpty {
                            emptyOverlay(colors: colors)
                        }
                    }
                } else {
                    DayView(
                        term: term,
                        profile: store.timingProfile,
                        date: selectedDay,
                        onOpenCourse: { detailCourseID = $0 }
                    )
                }
            } else {
                ContentUnavailableView(
                    "schedule.noTerm.title",
                    systemImage: "calendar.badge.plus",
                    description: Text("schedule.noTerm.message")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .gesture(horizontalSwipe)
    }

    private var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                let forward = value.translation.width < -50
                let backward = value.translation.width > 50
                guard forward || backward else { return }
                let delta = forward ? 1 : -1

                withAnimation(.easeOut(duration: 0.18)) {
                    if viewMode == .week {
                        displayWeekStart = ScheduleCalendar.addWeeks(delta, to: displayWeekStart)
                    } else {
                        selectedDay = ScheduleCalendar.addDays(delta, to: selectedDay)
                    }
                }
            }
    }

    private func emptyOverlay(colors: AppColors) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .appFont(26, weight: .regular)
                .foregroundStyle(colors.primary)
                .frame(width: 58, height: 58)
                .background(Circle().fill(colors.primaryContainer))

            Text("schedule.empty.title")
                .appFont(16, weight: .semibold)
                .foregroundStyle(colors.onSurface)

            Text("schedule.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            Button {
                editorTarget = CourseEditorTarget(
                    course: nil,
                    slot: CourseTimeSlot(dayOfWeek: defaultDay, startNode: 1, endNode: 2)
                )
            } label: {
                Text("schedule.addFirst")
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Capsule().fill(colors.primary))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(22)
        .frame(maxWidth: 290)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.10), radius: 18, y: 6)
        )
        .padding(24)
    }

    // MARK: - Week state

    private var displayedWeekNumber: Int? {
        guard let start = term?.startDateValue else { return nil }
        return displayWeekTermIndex(termStart: start, displayWeekStart: displayWeekStart)
    }

    private var currentWeekNumber: Int? {
        guard let start = term?.startDateValue else { return nil }
        return ScheduleCalendar.teachingWeekNumber(termStart: start, date: .now)
    }

    private var weekLabelText: String {
        guard let week = displayedWeekNumber else {
            return String(localized: "week.termStartMissing")
        }
        if week < 1 {
            return String(localized: "week.notStarted")
        }
        return String(format: String(localized: "week.number"), week)
    }

    private func displayedDays() -> [Date] {
        let days = columnDayOfWeeks(
            weekStart: preferences.weekStart,
            showWeekend: preferences.showWeekend,
            showSaturday: preferences.showSaturday
        )
        return days.map {
            columnDate(
                displayWeekStart: displayWeekStart,
                dayOfWeek: $0,
                weekStart: preferences.weekStart
            )
        }
    }

    // MARK: - Editing

    /// Drag-and-drop moves create a move override for the displayed week only,
    /// so the rest of the term keeps the original slot.
    private func moveCourse(_ course: CourseItem, toDay day: Int, startNode: Int, term: Term) {
        let span = course.time.nodeRange.count
        let sourceDate = columnDate(
            displayWeekStart: displayWeekStart,
            dayOfWeek: course.time.dayOfWeek,
            weekStart: preferences.weekStart
        )
        let targetDate = columnDate(
            displayWeekStart: displayWeekStart,
            dayOfWeek: day,
            weekStart: preferences.weekStart
        )
        guard !Calendar.current.isDate(sourceDate, inSameDayAs: targetDate)
                || startNode != course.time.nodeRange.lowerBound else {
            return
        }

        let plan = planCourseMove(
            overrides: store.state.overrides,
            courseId: course.id,
            from: sourceDate,
            to: targetDate,
            toStartNode: startNode,
            toEndNode: startNode + span - 1,
            naturalStartNode: course.time.startNode,
            naturalEndNode: course.time.endNode,
            newId: { UUID().uuidString }
        )
        for id in plan.removeIds {
            store.deleteOverride(id: id)
        }
        if let upsert = plan.upsert {
            store.upsertOverride(upsert)
        }
    }

    private func commit(_ result: CourseEditorResult, target: CourseEditorTarget) {
        if let course = result.course {
            if let original = target.course {
                var updated = course
                updated.id = original.id
                store.updateCourse(updated)
            } else {
                store.addCourse(course)
            }
        } else if result.deleted, let original = target.course {
            store.deleteCourse(id: original.id)
        }
    }
}

enum ScheduleViewMode: String, CaseIterable {
    case week
    case day
}
