import CurSimpleCore
import SwiftUI

enum MemoEditorResult {
    case saved(MemoNote)
    case deleted
}

/// Memo editor: title, body with checklist helpers, course binding, priority, deadline.
struct MemoEditorView: View {

    let existing: MemoNote
    let onCommit: (MemoEditorResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var bodyText = ""
    @State private var courseKey: String?
    @State private var priority: MemoPriority = .none
    @State private var pinned = false
    @State private var hasDue = false
    @State private var dueDate: Date = .now
    @State private var completed = false
    @State private var loaded = false
    @State private var showDeleteConfirm = false
    @State private var newItemText = ""

    private var isNew: Bool {
        existing.createdAt == 0 && existing.updatedAt == 0 && existing.isBlank
    }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        contentCard(colors: colors)
                        attributesCard(colors: colors)

                        if !isNew {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("memo.delete")
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
            "memo.delete.confirm",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("memo.delete", role: .destructive) {
                onCommit(.deleted)
                dismiss()
            }
        } message: {
            Text("memo.delete.message")
        }
        .onAppear(perform: load)
    }

    private func topBar(colors: AppColors) -> some View {
        ZStack {
            Text(isNew ? "memo.new" : "memo.edit")
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

    // MARK: - Sections

    private func contentCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            TextField("memo.titlePlaceholder", text: $title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colors.onSurface)

            Divider().overlay(colors.outlineVariant).padding(.vertical, 6)

            TextField("memo.bodyPlaceholder", text: $bodyText, axis: .vertical)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
                .lineLimit(6...14)

            Divider().overlay(colors.outlineVariant).padding(.vertical, 6)

            HStack(spacing: 8) {
                TextField("memo.newItemPlaceholder", text: $newItemText)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurface)
                    .onSubmit(addChecklistItem)

                Button {
                    addChecklistItem()
                } label: {
                    Image(systemName: "checklist")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colors.onPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(colors.primary))
                }
                .buttonStyle(.plain)
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newItemText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                .accessibilityLabel("memo.addItem")
            }
        }
    }

    private func attributesCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            courseRow(colors: colors)
            Divider().overlay(colors.outlineVariant).padding(.vertical, 2)

            priorityRow(colors: colors)
            Divider().overlay(colors.outlineVariant).padding(.vertical, 2)

            dueRow(colors: colors)
            Divider().overlay(colors.outlineVariant).padding(.vertical, 2)

            Toggle(isOn: $pinned) {
                Text("memo.pinned")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
            }
            .tint(colors.primary)
            .padding(.vertical, 6)

            Toggle(isOn: $completed) {
                Text("memo.completed")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
            }
            .tint(colors.primary)
            .padding(.vertical, 6)
        }
    }

    private func courseRow(colors: AppColors) -> some View {
        Menu {
            Button("memo.course.none") {
                courseKey = nil
            }
            ForEach(courseTitles, id: \.key) { course in
                Button(course.title) {
                    courseKey = course.key
                }
            }
        } label: {
            HStack {
                Text("memo.course")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                Text(courseLabel)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(courseKey == nil ? colors.onSurfaceVariant : colors.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .frame(minHeight: 44)
        }
    }

    private func priorityRow(colors: AppColors) -> some View {
        HStack {
            Text("memo.priority")
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            Spacer()
            HStack(spacing: 6) {
                ForEach(MemoPriority.allCases.filter { $0 != .none }) { value in
                    let selected = priority == value
                    Button {
                        priority = selected ? .none : value
                    } label: {
                        Circle()
                            .fill(priorityColor(value, colors: colors))
                            .frame(width: 22, height: 22)
                            .overlay {
                                if selected {
                                    Circle().stroke(colors.onSurface, lineWidth: 2).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(value.localizationKey)))
                }
            }
        }
        .frame(minHeight: 44)
    }

    private func dueRow(colors: AppColors) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: $hasDue.animation(.easeOut(duration: 0.18))) {
                Text("memo.due")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
            }
            .tint(colors.primary)
            .padding(.vertical, 6)

            if hasDue {
                Divider().overlay(colors.outlineVariant)
                DatePicker(
                    "",
                    selection: $dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Derived

    private var courseTitles: [(key: String, title: String)] {
        var seen = Set<String>()
        return store.state.terms.flatMap(\.courses)
            .filter { !$0.hidden }
            .compactMap { course -> (String, String)? in
                let key = memoCourseKey(course.title)
                guard !key.isEmpty, seen.insert(key).inserted else { return nil }
                return (key, course.title)
            }
    }

    private var courseLabel: String {
        guard let courseKey else { return String(localized: "memo.course.none") }
        return courseTitles.first { $0.key == courseKey }?.title ?? courseKey
    }

    private func priorityColor(_ priority: MemoPriority, colors: AppColors) -> Color {
        switch priority {
        case .high: colors.error
        case .medium: Color(red: 0.89, green: 0.60, blue: 0.18)
        case .low: colors.primary
        case .none: .clear
        }
    }

    // MARK: - Actions

    private func addChecklistItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        bodyText = MemoChecklist.appendingItem(bodyText, text: text)
        newItemText = ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        title = existing.title
        bodyText = existing.body
        courseKey = existing.courseKey
        priority = existing.priority
        pinned = existing.pinned
        completed = existing.completed
        if let due = existing.dueDateTime() {
            hasDue = true
            dueDate = due
        }
    }

    private func save() {
        var note = existing
        note.title = title.trimmingCharacters(in: .whitespaces)
        note.body = bodyText
        note.courseKey = courseKey
        note.courseTitle = courseKey.flatMap { key in
            courseTitles.first { $0.key == key }?.title
        } ?? ""
        note.priority = priority
        note.pinned = pinned
        note.completed = completed
        note.dueAt = hasDue ? Self.dueString(from: dueDate) : nil

        if note.title.isEmpty, note.body.isEmpty {
            dismiss()
            return
        }
        if note.title.isEmpty {
            note.title = note.displayTitle
        }
        onCommit(.saved(note))
        dismiss()
    }

    private static func dueString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        return formatter.string(from: date)
    }
}
