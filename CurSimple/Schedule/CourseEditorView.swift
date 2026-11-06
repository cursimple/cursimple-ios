import CurSimpleCore
import SwiftUI

struct CourseEditorResult {
    var course: CourseItem?
    var deleted: Bool = false
}

/// Course editor using the shared card-and-pill visual language.
struct CourseEditorView: View {

    let editing: CourseItem?
    let initialSlot: CourseTimeSlot
    let onCommit: (CourseEditorResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var teacher = ""
    @State private var location = ""
    @State private var category: CourseCategory = .course
    @State private var dayOfWeek = 1
    @State private var startNode = 1
    @State private var endNode = 2
    @State private var useAllWeeks = true
    @State private var weekSelection: Set<Int> = []
    @State private var useTypedClock = false
    @State private var typedStart = TimeOfDay(hour: 8, minute: 0)
    @State private var typedEnd = TimeOfDay(hour: 9, minute: 40)
    @State private var colorArgb: UInt32?
    @State private var showDeleteConfirm = false
    @State private var showTitleError = false
    @State private var loaded = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        basicSection(colors: colors)
                        timeSection(colors: colors)
                        weeksSection(colors: colors)
                        colorSection(colors: colors)

                        if let conflict = firstConflict {
                            ConflictCard(conflict: conflict, colors: colors)
                        }

                        if editing != nil {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("course.delete")
                                    Spacer()
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(colors.error)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(colors.surface)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
                }
            }
        }
        .confirmationDialog(
            "course.delete.confirm",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("course.delete", role: .destructive) {
                onCommit(CourseEditorResult(course: nil, deleted: true))
                dismiss()
            }
        } message: {
            Text("course.delete.message")
        }
        .onAppear(perform: load)
    }

    // MARK: - Chrome

    private func topBar(colors: AppColors) -> some View {
        ZStack {
            Text(editing == nil ? "course.new" : "course.edit")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colors.onBackground)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colors.onBackground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.cancel")

                Spacer()

                Button(action: save) {
                    Text("common.save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colors.onPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 8)
    }

    private func sectionTitle(_ key: LocalizedStringKey, colors: AppColors) -> some View {
        Text(key)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(colors.primary)
            .padding(.leading, 2)
    }

    private func row<Content: View>(
        _ label: LocalizedStringKey,
        colors: AppColors,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 44)
    }

    private func divider(_ colors: AppColors) -> some View {
        Divider().overlay(colors.outlineVariant).padding(.vertical, 1)
    }

    private func chip(_ text: String, colors: AppColors) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(colors.primary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(colors.primaryContainer))
    }

    // MARK: - Sections

    private func basicSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("course.section.basic", colors: colors)

            SettingsCard(colors: colors) {
                row("course.field.title", colors: colors) {
                    TextField("course.field.title", text: $title)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(colors.onSurface)
                        .onChange(of: title) { _, _ in showTitleError = false }
                }

                if showTitleError {
                    Text("course.title.required")
                        .font(AppFont.label)
                        .foregroundStyle(colors.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                divider(colors)

                row("course.field.teacher", colors: colors) {
                    TextField("course.optional", text: $teacher)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(colors.onSurface)
                }

                divider(colors)

                row("course.field.location", colors: colors) {
                    TextField("course.optional", text: $location)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(colors.onSurface)
                }

                divider(colors)

                HStack(spacing: 8) {
                    Text("course.field.category")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    categoryPill(.course, colors: colors)
                    categoryPill(.exam, colors: colors)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func categoryPill(_ value: CourseCategory, colors: AppColors) -> some View {
        let selected = category == value
        return Button {
            category = value
        } label: {
            Text(value == .course ? "course.category.course" : "course.category.exam")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(selected ? colors.primary : colors.surfaceVariant))
        }
        .buttonStyle(.plain)
    }

    private func timeSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("course.section.time", colors: colors)

            SettingsCard(colors: colors) {
                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { day in
                        let selected = dayOfWeek == day
                        Button {
                            dayOfWeek = day
                        } label: {
                            Text(Format.weekdayNarrow(day))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected ? colors.primary : colors.surfaceVariant)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                divider(colors).padding(.vertical, 6)

                HStack(spacing: 10) {
                    Text("course.field.periods")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    periodMenu(startNode, colors: colors) { value in
                        startNode = value
                        if endNode < value { endNode = value }
                    }
                    Text("–")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(colors.onSurfaceVariant)
                    periodMenu(endNode, colors: colors) { value in
                        endNode = value
                        if startNode > value { startNode = value }
                    }
                }
                .frame(minHeight: 44)

                divider(colors)

                HStack {
                    Text("course.field.customClock")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    Toggle("", isOn: $useTypedClock.animation(.easeOut(duration: 0.18)))
                        .labelsHidden()
                        .tint(colors.primary)
                }
                .frame(minHeight: 44)

                if useTypedClock {
                    divider(colors)
                    TimePickerField(time: $typedStart, label: "course.field.startTime")
                        .font(AppFont.body)
                    divider(colors)
                    TimePickerField(time: $typedEnd, label: "course.field.endTime")
                        .font(AppFont.body)
                }
            }
        }
    }

    private func periodMenu(
        _ value: Int,
        colors: AppColors,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(1...maxNode, id: \.self) { node in
                Button(Format.period(node)) { onSelect(node) }
            }
        } label: {
            chip(Format.period(value), colors: colors)
        }
        .buttonStyle(.plain)
    }

    private func weeksSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("course.section.weeks", colors: colors)

            SettingsCard(colors: colors) {
                HStack {
                    Text("course.weeks.all")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    Toggle("", isOn: $useAllWeeks.animation(.easeOut(duration: 0.18)))
                        .labelsHidden()
                        .tint(colors.primary)
                }
                .frame(minHeight: 44)

                if !useAllWeeks {
                    divider(colors).padding(.bottom, 8)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                        spacing: 6
                    ) {
                        ForEach(1...max(termWeekCount, 1), id: \.self) { week in
                            weekChip(week, colors: colors)
                        }
                    }

                    HStack(spacing: 8) {
                        quickWeekButton("course.weeks.odd", colors: colors) {
                            weekSelection = Set(stride(from: 1, through: termWeekCount, by: 2))
                        }
                        quickWeekButton("course.weeks.even", colors: colors) {
                            weekSelection = Set(stride(from: 2, through: termWeekCount, by: 2))
                        }
                        quickWeekButton("course.weeks.all", colors: colors) {
                            weekSelection = Set(1...max(termWeekCount, 1))
                        }
                        quickWeekButton("course.weeks.clear", colors: colors) {
                            weekSelection = []
                        }
                    }
                    .padding(.top, 10)

                    if weekSelection.isEmpty {
                        Text("course.weeks.emptyHint")
                            .font(AppFont.label)
                            .foregroundStyle(colors.error)
                            .padding(.top, 8)
                    } else {
                        Text(Format.weekSummary(Array(weekSelection).sorted()))
                            .font(AppFont.label)
                            .foregroundStyle(colors.onSurfaceVariant)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }

    private func weekChip(_ week: Int, colors: AppColors) -> some View {
        let selected = weekSelection.contains(week)
        return Button {
            if selected {
                weekSelection.remove(week)
            } else {
                weekSelection.insert(week)
            }
        } label: {
            Text("\(week)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? colors.primary : colors.surfaceVariant)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func quickWeekButton(
        _ title: LocalizedStringKey,
        colors: AppColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(colors.primary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(colors.primaryContainer))
        }
        .buttonStyle(.plain)
    }

    private func colorSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("course.section.color", colors: colors)

            SettingsCard(colors: colors) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        autoSwatch(colors: colors)
                        ForEach(
                            CoursePalette.swatches(
                                for: store.preferences.paletteStyle,
                                dark: colorScheme == .dark
                            ),
                            id: \.self
                        ) { value in
                            swatch(value, colors: colors)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func autoSwatch(colors: AppColors) -> some View {
        Button {
            colorArgb = nil
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(colors.outline, style: StrokeStyle(lineWidth: 1, dash: [3]))
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .frame(width: 34, height: 34)
            .overlay {
                if colorArgb == nil {
                    Circle().stroke(colors.primary, lineWidth: 2).padding(-4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("course.color.auto")
    }

    private func swatch(_ value: UInt32, colors: AppColors) -> some View {
        Button {
            colorArgb = value
        } label: {
            Circle()
                .fill(RGBColor(argb: value).color)
                .frame(width: 34, height: 34)
                .overlay {
                    if colorArgb == value {
                        Circle().stroke(colors.primary, lineWidth: 2).padding(-4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("course.color.pick")
    }

    // MARK: - Derived

    private var maxNode: Int {
        max(store.timingProfile.slots.map(\.endNode).max() ?? 0, 12)
    }

    private var termWeekCount: Int {
        store.activeTerm?.weekCount ?? defaultTermWeekCount
    }

    private var firstConflict: CourseConflict? {
        guard let term = store.activeTerm else { return nil }
        let candidate = makeCourse()
        let others = term.courses.filter { $0.id != editing?.id }
        return conflicts(with: candidate, in: others, maxWeekCount: term.weekCount).first
    }

    private func makeCourse() -> CourseItem {
        var course = editing ?? CourseItem(
            title: title,
            time: CourseTimeSlot(dayOfWeek: dayOfWeek, startNode: startNode, endNode: endNode)
        )
        course.title = title.trimmingCharacters(in: .whitespaces)
        course.teacher = teacher.trimmingCharacters(in: .whitespaces)
        course.location = location.trimmingCharacters(in: .whitespaces)
        course.category = category
        course.time = CourseTimeSlot(
            dayOfWeek: dayOfWeek,
            startNode: min(startNode, endNode),
            endNode: max(startNode, endNode)
        )
        course.weeks = useAllWeeks ? [] : weekSelection.sorted()
        if useTypedClock {
            course.reminderStartTime = typedStart.text
            course.reminderEndTime = typedEnd.text
        } else {
            course.reminderStartTime = nil
            course.reminderEndTime = nil
        }
        course.colorArgb = colorArgb
        return course
    }

    // MARK: - Actions

    private func load() {
        guard !loaded else { return }
        loaded = true

        if let editing {
            title = editing.title
            teacher = editing.teacher
            location = editing.location
            category = editing.category
            dayOfWeek = editing.time.dayOfWeek
            startNode = editing.time.startNode
            endNode = editing.time.endNode
            useAllWeeks = editing.weeks.isEmpty
            weekSelection = Set(editing.weeks)
            if let typed = editing.typedClock {
                useTypedClock = true
                typedStart = typed.start
                typedEnd = typed.end
            }
            colorArgb = editing.colorArgb
        } else {
            dayOfWeek = initialSlot.dayOfWeek
            startNode = initialSlot.startNode
            endNode = initialSlot.endNode
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            showTitleError = true
            return
        }
        onCommit(CourseEditorResult(course: makeCourse()))
        dismiss()
    }
}

// MARK: - Conflict card

private struct ConflictCard: View {

    let conflict: CourseConflict
    let colors: AppColors

    var body: some View {
        let other = conflict.second
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(colors.error)

            VStack(alignment: .leading, spacing: 3) {
                Text("course.conflict.title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.onSurface)
                Text(String(
                    format: String(localized: "course.conflict.message"),
                    other.title,
                    Format.weekSummary(conflict.overlappingWeeks)
                ))
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.error.opacity(0.10))
        )
    }
}

// MARK: - Time picker

struct TimePickerField: View {

    @Binding var time: TimeOfDay
    let label: LocalizedStringKey

    var body: some View {
        DatePicker(
            label,
            selection: Binding(
                get: { time.date(on: .now) ?? .now },
                set: { time = TimeOfDay(date: $0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .environment(\.locale, Locale(identifier: "en_GB"))
    }
}
