import CurSimpleCore
import SwiftUI

struct CourseEditorResult {
    var course: CourseItem?
    var deleted: Bool = false
}

/// Full-screen editor for creating and editing a course.
struct CourseEditorView: View {

    let editing: CourseItem?
    let initialSlot: CourseTimeSlot
    let onCommit: (CourseEditorResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var title: String = ""
    @State private var teacher: String = ""
    @State private var location: String = ""
    @State private var category: CourseCategory = .course
    @State private var dayOfWeek: Int = 1
    @State private var startNode: Int = 1
    @State private var endNode: Int = 2
    @State private var weekSelection: Set<Int> = []
    @State private var useAllWeeks = true
    @State private var useTypedClock = false
    @State private var typedStart = TimeOfDay(hour: 8, minute: 0)
    @State private var typedEnd = TimeOfDay(hour: 9, minute: 40)
    @State private var colorArgb: UInt32?
    @State private var showDeleteConfirm = false
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("course.field.title", text: $title)
                    TextField("course.field.teacher", text: $teacher)
                    TextField("course.field.location", text: $location)
                    Picker("course.field.category", selection: $category) {
                        Text("course.category.course").tag(CourseCategory.course)
                        Text("course.category.exam").tag(CourseCategory.exam)
                    }
                } header: {
                    Text("course.section.basic")
                }

                Section {
                    Picker("course.field.day", selection: $dayOfWeek) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Format.weekday(day)).tag(day)
                        }
                    }
                    Picker("course.field.periods", selection: Binding(
                        get: { "\(startNode)-\(endNode)" },
                        set: { raw in
                            let parts = raw.split(separator: "-").compactMap { Int($0) }
                            if parts.count == 2 {
                                startNode = parts[0]
                                endNode = parts[1]
                            }
                        }
                    )) {
                        ForEach(periodRanges, id: \.key) { range in
                            Text(range.label).tag(range.key)
                        }
                    }
                    if useTypedClock {
                        TimePickerField(time: $typedStart, label: "course.field.startTime")
                        TimePickerField(time: $typedEnd, label: "course.field.endTime")
                    }
                    Toggle("course.field.customClock", isOn: $useTypedClock.animation(.easeOut(duration: 0.2)))
                } header: {
                    Text("course.section.time")
                }

                Section {
                    Toggle("course.weeks.all", isOn: $useAllWeeks.animation(.easeOut(duration: 0.2)))
                    if !useAllWeeks {
                        WeekSelector(selection: $weekSelection, maxWeek: termWeekCount)
                    }
                } header: {
                    Text("course.section.weeks")
                } footer: {
                    Text(weekFooter)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            swatch(nil, label: "course.color.auto")
                            ForEach(CoursePalette.swatches, id: \.self) { value in
                                swatch(value, label: nil)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("course.section.color")
                }

                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("course.delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "course.new" : "course.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && category == .course)
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
    }

    // MARK: - Data

    private var termWeekCount: Int {
        store.activeTerm?.weekCount ?? defaultTermWeekCount
    }

    private var periodRanges: [(key: String, label: String)] {
        let maxNode = max(profileMaxNode, 12)
        var ranges: [(key: String, label: String)] = []
        for start in 1...maxNode {
            for end in start...min(start + 4, maxNode) {
                let key = "\(start)-\(end)"
                var label = Format.periodRange(start, end)
                if let slot = store.timingProfile.slot(startNode: start, endNode: end),
                   let startTime = slot.start, let endTime = slot.end {
                    label += "  \(startTime)–\(endTime)"
                }
                ranges.append((key, label))
            }
        }
        return ranges
    }

    private var profileMaxNode: Int {
        store.timingProfile.slots.map(\.endNode).max() ?? 0
    }

    private var weekFooter: String {
        if useAllWeeks { return "" }
        if weekSelection.isEmpty {
            return String(localized: "course.weeks.emptyHint")
        }
        return Format.weekSummary(Array(weekSelection).sorted())
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

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
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let weeks = useAllWeeks ? [] : Array(weekSelection).sorted()

        var course = editing ?? CourseItem(title: trimmedTitle, time: CourseTimeSlot(dayOfWeek: dayOfWeek, startNode: startNode, endNode: endNode))
        course.title = trimmedTitle
        course.teacher = teacher.trimmingCharacters(in: .whitespaces)
        course.location = location.trimmingCharacters(in: .whitespaces)
        course.category = category
        course.time = CourseTimeSlot(dayOfWeek: dayOfWeek, startNode: startNode, endNode: endNode)
        course.weeks = weeks
        course.slotLabelOverride = nil
        if useTypedClock {
            course.reminderStartTime = typedStart.text
            course.reminderEndTime = typedEnd.text
        } else {
            course.reminderStartTime = nil
            course.reminderEndTime = nil
        }
        course.colorArgb = colorArgb

        onCommit(CourseEditorResult(course: course))
        dismiss()
    }

    private func swatch(_ value: UInt32?, label: LocalizedStringKey?) -> some View {
        Button {
            colorArgb = value
        } label: {
            ZStack {
                if let value {
                    Circle()
                        .fill(RGBColor(argb: value).color)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .frame(width: 32, height: 32)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if colorArgb == value {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2).frame(width: 38, height: 38)
                }
            }
            .frame(width: AppMetrics.touchTarget, height: AppMetrics.touchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "course.color.pick")
    }
}

// MARK: - Week selector

struct WeekSelector: View {

    @Binding var selection: Set<Int>
    let maxWeek: Int

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...maxWeek, id: \.self) { week in
                    let isOn = selection.contains(week)
                    Button {
                        if isOn {
                            selection.remove(week)
                        } else {
                            selection.insert(week)
                        }
                    } label: {
                        Text("\(week)")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isOn ? Color.accentColor : Color(.tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(week)")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }

            HStack(spacing: 8) {
                Button("course.weeks.odd") {
                    selection = Set((1...maxWeek).filter { $0 % 2 == 1 })
                }
                Button("course.weeks.even") {
                    selection = Set((1...maxWeek).filter { $0 % 2 == 0 })
                }
                Button("course.weeks.all") {
                    selection = Set(1...maxWeek)
                }
                Button("course.weeks.clear") {
                    selection = []
                }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
            .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TimeOfDay picker binding

extension TimeOfDay: @retroactive Identifiable {
    public var id: Int { minutes }
}

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
    }
}
