import CurSimpleCore
import SwiftUI

/// Course details matching the shared layout: tinted header card, grouped info
/// rows, a note entry and a four-action footer.
struct CourseDetailView: View {

    let course: CourseItem
    let term: Term?
    let onSave: (CourseItem) -> Void
    let onDelete: () -> Void
    let onHide: () -> Void
    /// Opens the editor for this course; supplied by the presenting view.
    var onEdit: (() -> Void)?
    /// Cancels only today's occurrence through a temporary override.
    var onCancelToday: ((CourseItem) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var noteText = ""
    @State private var showNoteEditor = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let entry = CoursePalette.courseEntry(
            for: course,
            style: store.preferences.paletteStyle,
            dark: colorScheme == .dark
        )

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        headerCard(entry: entry, colors: colors)
                        infoCard(colors: colors)
                        noteCard(colors: colors)

                        if let conflict = firstConflict, let conflictDescription {
                            conflictCard(conflictDescription, colors: colors)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                actionBar(colors: colors)
            }
        }
        .onAppear {
            if !noteTextInitialized {
                noteText = course.details.first { $0.label == "备注" }?.value ?? ""
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            CourseNoteEditor(note: $noteText) {
                var updated = course
                updated.details = course.details.filter { $0.label != "备注" }
                if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updated.details.append(CourseDetailField(label: "备注", value: noteText))
                }
                onSave(updated)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private func headerCard(entry: CoursePaletteEntry, colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(course.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(entry.onContainer.color)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if course.category != .course {
                    Text(LocalizedStringKey(course.category.localizationKey))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entry.onContainer.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(entry.onContainer.color.opacity(0.16)))
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(entry.onContainer.color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(entry.onContainer.color.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.done")
            }

            if !course.teacher.isEmpty {
                Text(course.teacher)
                    .font(.system(size: 13))
                    .foregroundStyle(entry.onContainer.color.opacity(0.75))
            }

            Text(summaryLine)
                .font(.system(size: 13))
                .foregroundStyle(entry.onContainer.color.opacity(0.75))

            if let progressLine {
                Text(progressLine)
                    .font(.system(size: 13))
                    .foregroundStyle(entry.onContainer.color.opacity(0.75))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(entry.container.color)
        )
    }

    // MARK: - Info

    private func infoCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            infoRow(icon: "clock", title: "course.detail.time", value: timeLine, colors: colors)
            divider(colors)
            infoRow(icon: "calendar", title: "course.detail.weeks", value: weekLine, colors: colors)
            divider(colors)
            infoRow(icon: "mappin.and.ellipse", title: "course.field.location", value: locationLine, colors: colors)
            divider(colors)
            infoRow(icon: "person", title: "course.field.teacher", value: teacherLine, colors: colors)
            if !course.details.filter({ $0.label != "备注" }).isEmpty {
                divider(colors)
                ForEach(course.details.filter { $0.label != "备注" }) { detail in
                    infoRow(
                        icon: "info.circle",
                        title: LocalizedStringKey(detail.label),
                        value: detail.value,
                        colors: colors
                    )
                    divider(colors)
                }
            }
            infoRow(icon: "tray", title: "course.detail.source", value: sourceLine, colors: colors)
        }
    }

    private func infoRow(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        colors: AppColors
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(colors.primary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(colors.onSurfaceVariant)
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }

    private func divider(_ colors: AppColors) -> some View {
        Divider().overlay(colors.outlineVariant)
    }

    // MARK: - Note

    private func noteCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.primary)
                Text("course.detail.note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.onSurfaceVariant)
                Spacer()
                Button {
                    showNoteEditor = true
                } label: {
                    Text(noteText.isEmpty ? "course.detail.noteAdd" : "course.detail.noteEdit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colors.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .overlay(Capsule().stroke(colors.primary.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if noteText.isEmpty {
                Text("course.detail.noteEmpty")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .padding(.top, 6)
            } else {
                Text(noteText)
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }

    private func conflictCard(_ message: String, colors: AppColors) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(colors.error)
            VStack(alignment: .leading, spacing: 3) {
                Text("course.conflict.title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.onSurface)
                Text(message)
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

    // MARK: - Actions

    private func actionBar(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            actionButton("course.detail.edit", icon: "pencil", colors: colors) {
                dismiss()
                onEdit?()
            }
            actionButton("course.detail.reminder", icon: "bell", colors: colors) {
                dismiss()
            }
            actionButton("course.detail.cancelToday", icon: "xmark", colors: colors) {
                onCancelToday?(course)
                dismiss()
            }
            actionButton("course.delete", icon: "trash", tint: colors.error, colors: colors) {
                onDelete()
                dismiss()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(colors.background)
    }

    private func actionButton(
        _ title: LocalizedStringKey,
        icon: String,
        tint: Color? = nil,
        colors: AppColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint ?? colors.onSurface)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke((tint ?? colors.outlineVariant).opacity(tint == nil ? 1 : 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var noteTextInitialized: Bool { !noteText.isEmpty }

    private var summaryLine: String {
        var parts = [Format.weekday(course.time.dayOfWeek)]
        if let clock = occurrenceClock(for: course, profile: store.timingProfile) {
            parts.append("\(Format.periodRange(course.time.startNode, course.time.endNode))")
            parts.append("\(clock.start.text)-\(clock.end.text)")
        } else {
            parts.append(Format.periodRange(course.time.startNode, course.time.endNode))
        }
        return parts.joined(separator: " · ")
    }

    private var progressLine: String? {
        guard let term, let termStart = term.startDateValue else { return nil }
        let current = ScheduleCalendar.teachingWeekNumber(termStart: termStart, date: .now)
        let active = course.weeks.filter { $0 >= 1 && $0 <= term.weekCount }
        guard !active.isEmpty else { return nil }
        let total = active.count
        let passed = active.filter { $0 <= current }.count
        guard passed > 0 else { return nil }
        return String(format: String(localized: "course.detail.sessions"), passed, total)
    }

    private var timeLine: String {
        guard let clock = occurrenceClock(for: course, profile: store.timingProfile) else { return "" }
        return "\(clock.start.text) - \(clock.end.text)"
    }

    private var weekLine: String {
        guard let term else { return Format.weekSummary(course.weeks) }
        let active = course.weeks.isEmpty ? Array(1...term.weekCount) : course.weeks
        guard let first = active.min(), let last = active.max() else {
            return Format.weekSummary(course.weeks)
        }
        if first == last {
            return String(format: String(localized: "course.detail.weekOne"), first)
        }
        return String(format: String(localized: "course.detail.weekRange"), first, last, active.count)
    }

    private var locationLine: String {
        let week = term?.weekNumber(on: .now, calendar: .current)
        return course.location(forWeek: week)
    }

    private var teacherLine: String {
        let week = term?.weekNumber(on: .now, calendar: .current)
        return course.teacher(forWeek: week)
    }

    private var sourceLine: String {
        String(localized: "course.detail.source.manual")
    }

    private var firstConflict: CourseConflict? {
        guard let term else { return nil }
        return conflicts(
            with: course,
            in: term.courses.filter { $0.id != course.id },
            maxWeekCount: term.weekCount
        ).first
    }

    private var conflictDescription: String? {
        guard let firstConflict else { return nil }
        let other = firstConflict.second
        return String(
            format: String(localized: "course.conflict.message"),
            other.title,
            Format.weekSummary(firstConflict.overlappingWeeks)
        )
    }
}

// MARK: - Note editor

private struct CourseNoteEditor: View {

    @Binding var note: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStore.self) private var store

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("course.detail.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.onBackground)
                    HStack {
                        Button("common.cancel") { dismiss() }
                            .font(.system(size: 14))
                            .foregroundStyle(colors.primary)
                        Spacer()
                        Button("common.save") {
                            onSave()
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colors.primary)
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 16)

                TextEditor(text: $note)
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colors.surface)
                    )
                    .padding(.horizontal, 16)
                    .frame(maxHeight: 240)

                Spacer(minLength: 0)
            }
        }
    }
}
