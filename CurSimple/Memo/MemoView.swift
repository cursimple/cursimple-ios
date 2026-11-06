import CurSimpleCore
import SwiftUI

/// Memo list with course filter, search, due badges and checklist progress.
struct MemoView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var filter: MemoFilter = .active
    @State private var courseFilter: String?
    @State private var editingNote: MemoNote? = ProcessInfo.processInfo.arguments.contains("-openMemoEditor")
        ? MemoNote()
        : nil

    enum MemoFilter: String, CaseIterable, Identifiable {
        case active
        case today
        case done

        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .active: "memo.filter.active"
            case .today: "memo.filter.today"
            case .done: "memo.filter.done"
            }
        }
    }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("tab.memo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.onBackground)

                    HStack {
                        Button(action: onOpenDrawer) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(colors.onBackground)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("drawer.open")

                        Spacer()

                        Button {
                            editingNote = MemoNote()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(colors.onSurface)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(colors.surface))
                                .overlay(Circle().stroke(colors.outlineVariant, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("memo.add")
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 6)

                filterRow(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        if visibleNotes.isEmpty {
                            emptyState(colors: colors)
                        } else {
                            ForEach(visibleNotes) { note in
                                MemoCard(note: note) {
                                    editingNote = note
                                } onToggleChecklist: { itemText in
                                    store.toggleMemoChecklist(noteID: note.id, itemText: itemText)
                                } onTogglePin: {
                                    var updated = note
                                    updated.pinned.toggle()
                                    updated.updatedAt = nowMillis()
                                    store.upsertMemo(updated)
                                } onToggleComplete: {
                                    var updated = note
                                    updated.completed.toggle()
                                    updated.updatedAt = nowMillis()
                                    store.upsertMemo(updated)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(item: $editingNote) { note in
            MemoEditorView(existing: note) { result in
                switch result {
                case .saved(let saved):
                    var updated = saved
                    if updated.createdAt == 0 {
                        updated.createdAt = nowMillis()
                    }
                    updated.updatedAt = nowMillis()
                    store.upsertMemo(updated)
                case .deleted:
                    store.deleteMemo(id: note.id)
                }
            }
            .presentationDetents([.large])
        }
    }

    private func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - Derived

    private var visibleNotes: [MemoNote] {
        let now = Date()
        var notes = store.sortedMemos(now: now)

        switch filter {
        case .active:
            notes = notes.filter { !$0.completed }
        case .today:
            notes = notes.filter {
                let state = $0.dueState(at: now)
                return state == .overdue || state == .today
            }
        case .done:
            notes = notes.filter(\.completed)
        }

        if let courseFilter {
            notes = notes.filter { $0.courseKey == courseFilter }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let key = query.lowercased()
            notes = notes.filter {
                $0.title.lowercased().contains(key)
                    || $0.body.lowercased().contains(key)
                    || $0.courseTitle.lowercased().contains(key)
            }
        }
        return notes
    }

    // MARK: - Chrome

    private func filterRow(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            ForEach(MemoFilter.allCases) { item in
                let selected = filter == item
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        filter = item
                    }
                } label: {
                    Text(item.titleKey)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(Capsule().fill(selected ? colors.primary : colors.surfaceVariant))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if courseFilter != nil {
                Button {
                    courseFilter = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("memo.clearCourseFilter")
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func emptyState(colors: AppColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 24))
                .foregroundStyle(colors.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(colors.primaryContainer))

            Text("memo.empty.title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
            Text("memo.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Card

struct MemoCard: View {

    let note: MemoNote
    let action: () -> Void
    let onToggleChecklist: (String) -> Void
    let onTogglePin: () -> Void
    let onToggleComplete: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let checklist = note.checklist
        let due = note.dueState(at: Date())

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Complete toggle
                Button {
                    onToggleComplete()
                } label: {
                    Image(systemName: note.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19))
                        .foregroundStyle(note.completed ? colors.primary : colors.outline)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .accessibilityLabel("memo.toggleComplete")

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if note.pinned && !note.completed {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(colors.primary)
                        }
                        Text(note.displayTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(note.completed ? colors.onSurfaceVariant : colors.onSurface)
                            .strikethrough(note.completed, color: colors.onSurfaceVariant)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        if !note.courseTitle.isEmpty {
                            Text(note.courseTitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(colors.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(colors.primaryContainer))
                        }
                        if let dueText = dueBadgeText(due) {
                            Text(dueText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(dueColor(due, colors: colors))
                        }
                        if checklist.hasItems {
                            Text(String(
                                format: String(localized: "memo.checklistProgress"),
                                checklist.done,
                                checklist.total
                            ))
                            .font(AppFont.label)
                            .foregroundStyle(colors.onSurfaceVariant)
                        }
                    }
                }

                Spacer(minLength: 0)

                Menu {
                    Button(note.pinned ? "memo.unpin" : "memo.pin") { onTogglePin() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colors.onSurfaceVariant)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                }
            }

            if checklist.hasItems {
                VStack(spacing: 0) {
                    let lines = note.body.components(separatedBy: "\n")
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        if let parsed = MemoChecklist.parseLine(line) {
                            Button {
                                onToggleChecklist(parsed.text)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: parsed.checked ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 14))
                                        .foregroundStyle(parsed.checked ? colors.primary : colors.outline)
                                    Text(parsed.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(parsed.checked ? colors.onSurfaceVariant : colors.onSurface)
                                        .strikethrough(parsed.checked, color: colors.onSurfaceVariant)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.leading, 36)
            } else {
                Text(plainPreview)
                    .font(.system(size: 13))
                    .foregroundStyle(colors.onSurfaceVariant)
                    .lineLimit(2)
                    .padding(.leading, 36)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
        .overlay(alignment: .leading) {
            if note.priority != .none {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityColor(note.priority, colors: colors))
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: action)
    }

    private var plainPreview: String {
        let lines = note.body
            .components(separatedBy: "\n")
            .filter { MemoChecklist.parseLine($0) == nil && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.prefix(2).joined(separator: "\n")
    }

    private func dueBadgeText(_ state: MemoDueState) -> String? {
        switch state {
        case .overdue: String(localized: "memo.due.overdue")
        case .today: String(localized: "memo.due.today")
        case .soon: String(localized: "memo.due.soon")
        case .none, .later: nil
        }
    }

    private func dueColor(_ state: MemoDueState, colors: AppColors) -> Color {
        switch state {
        case .overdue: colors.error
        case .today: .orange
        case .soon: colors.primary
        case .none, .later: colors.onSurfaceVariant
        }
    }

    private func priorityColor(_ priority: MemoPriority, colors: AppColors) -> Color {
        switch priority {
        case .high: colors.error
        case .medium: Color(red: 0.89, green: 0.60, blue: 0.18)
        case .low: colors.primary
        case .none: .clear
        }
    }
}
