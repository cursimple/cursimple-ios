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
                dialogHeader(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        chipsRow(colors: colors)
                        nameField(colors: colors)
                        locationField(colors: colors)
                        teacherField(colors: colors)
                        modeRow(colors: colors)

                        if useTypedClock {
                            clockFields(colors: colors)
                        } else {
                            periodsRow(colors: colors)
                        }

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
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(colors.error.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }

                dialogActions(colors: colors)
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

    private func dialogHeader(colors: AppColors) -> some View {
        Text(editing == nil ? "course.new" : "course.edit")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(colors.onBackground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
    }

    private func dialogActions(colors: AppColors) -> some View {
        HStack(spacing: 12) {
            Spacer()

            Button {
                dismiss()
            } label: {
                Text("common.cancel")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(colors.primary)
                    .padding(.horizontal, 26)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(colors.primary.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: save) {
                Text("common.save")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 30)
                    .frame(height: 44)
                    .background(Capsule().fill(colors.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    /// Type, weekday and period chips shown under the title.
    private func chipsRow(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                categoryChip(.course, colors: colors)
                categoryChip(.exam, colors: colors)
                Spacer()
            }

            HStack(spacing: 8) {
                chip(Format.weekday(dayOfWeek), colors: colors) { _ in }
                    .overlay {
                        Menu {
                            ForEach(1...7, id: \.self) { day in
                                Button(Format.weekday(day)) { dayOfWeek = day }
                            }
                        } label: { Color.clear }
                    }
                chip(Format.periodRange(startNode, endNode), colors: colors) { _ in }
                    .overlay {
                        Menu {
                            ForEach(1...maxNode, id: \.self) { start in
                                ForEach(start...maxNode, id: \.self) { end in
                                    Button(Format.periodRange(start, end)) {
                                        startNode = start
                                        endNode = end
                                    }
                                }
                            }
                        } label: { Color.clear }
                    }
                Spacer()
            }
        }
    }

    private func categoryChip(_ value: CourseCategory, colors: AppColors) -> some View {
        let selected = category == value
        return Button {
            category = value
        } label: {
            Text(value == .course ? "course.category.course" : "course.category.exam")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(Capsule().fill(selected ? colors.primary : Color.clear))
                .overlay(Capsule().stroke(selected ? Color.clear : colors.outlineVariant, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func borderedField(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        colors: AppColors,
        required: Bool = false
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15))
            .foregroundStyle(colors.onSurface)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(required && text.wrappedValue.isEmpty ? colors.primary : colors.outlineVariant, lineWidth: 1)
            )
    }

    private func nameField(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            borderedField("course.field.title", text: $title, colors: colors, required: true)
                .onChange(of: title) { _, _ in showTitleError = false }
            if showTitleError {
                Text("course.title.required")
                    .font(AppFont.label)
                    .foregroundStyle(colors.error)
            }
        }
    }

    private func locationField(colors: AppColors) -> some View {
        borderedField("course.field.location", text: $location, colors: colors)
    }

    private func teacherField(colors: AppColors) -> some View {
        borderedField("course.field.teacher", text: $teacher, colors: colors)
    }

    private func modeRow(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            modeChip("course.field.periods", selected: !useTypedClock, colors: colors) {
                useTypedClock = false
            }
            modeChip("course.field.byTime", selected: useTypedClock, colors: colors) {
                useTypedClock = true
            }
            Spacer()
        }
    }

    private func modeChip(
        _ title: LocalizedStringKey,
        selected: Bool,
        colors: AppColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? colors.primary : colors.onSurfaceVariant)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .overlay(
                    Capsule().stroke(
                        selected ? colors.primary : colors.outlineVariant,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func periodsRow(colors: AppColors) -> some View {
        HStack(spacing: 10) {
            Text("course.field.periods")
                .font(.system(size: 14))
                .foregroundStyle(colors.onSurfaceVariant)
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
    }

    private func clockFields(colors: AppColors) -> some View {
        HStack(spacing: 12) {
            clockBox("course.field.startTime", time: $typedStart, colors: colors)
            clockBox("course.field.endTime", time: $typedEnd, colors: colors)
        }
    }

    private func clockBox(
        _ title: LocalizedStringKey,
        time: Binding<TimeOfDay>,
        colors: AppColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(colors.onSurfaceVariant)
            TimePickerField(time: time, label: title)
                .labelsHidden()
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(colors.outlineVariant, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
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

    private func chip(
        _ text: String,
        colors: AppColors,
        action: @escaping (Int) -> Void = { _ in }
    ) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(colors.primary)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(Capsule().fill(colors.primaryContainer))
    }

    // MARK: - Sections

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
            Text(Format.period(value))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(colors.primary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(colors.primaryContainer))
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
