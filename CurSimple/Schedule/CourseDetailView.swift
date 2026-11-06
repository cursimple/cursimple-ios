import CurSimpleCore
import SwiftUI

/// Course details in the shared card style.
struct CourseDetailView: View {

    let course: CourseItem
    let term: Term?
    let onSave: (CourseItem) -> Void
    let onDelete: () -> Void
    let onHide: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

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
                topBar(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        headerCard(entry: entry, colors: colors)
                        infoCard(colors: colors)

                        if let conflict = firstConflict, let conflictDescription {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(colors.error)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("course.conflict.title")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(colors.onSurface)
                                    Text(conflictDescription)
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

                        Button {
                            onHide()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "eye.slash")
                                Text("course.hide")
                                Spacer()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(colors.onSurface)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(colors.surface)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onDelete()
                            dismiss()
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
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func topBar(colors: AppColors) -> some View {
        ZStack {
            Text("course.detail")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colors.onBackground)

            HStack {
                Spacer()
                Button("common.done") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colors.primary)
                    .frame(height: 44)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
    }

    private func headerCard(entry: CoursePaletteEntry, colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(course.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(entry.onContainer.color)
                    .multilineTextAlignment(.leading)

                if course.category == .exam {
                    Text("course.examTag")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(entry.container.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(entry.onContainer.color))
                }

                Spacer(minLength: 0)
            }

            Text(summaryLine)
                .font(.system(size: 13))
                .foregroundStyle(entry.onContainer.color.opacity(0.78))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(entry.container.color)
        )
    }

    private func infoCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            if !course.teacher.isEmpty {
                infoRow(icon: "person", title: "course.field.teacher", value: course.teacher, colors: colors)
                Divider().overlay(colors.outlineVariant).padding(.vertical, 3)
            }
            if !course.location.isEmpty {
                infoRow(icon: "mappin.and.ellipse", title: "course.field.location", value: course.location, colors: colors)
                Divider().overlay(colors.outlineVariant).padding(.vertical, 3)
            }
            infoRow(
                icon: "number",
                title: "course.field.weeks",
                value: Format.weekSummary(course.weeks),
                colors: colors
            )
            if !course.details.isEmpty {
                ForEach(course.details) { detail in
                    Divider().overlay(colors.outlineVariant).padding(.vertical, 3)
                    infoRow(
                        icon: "info.circle",
                        title: LocalizedStringKey(detail.label),
                        value: detail.value,
                        colors: colors
                    )
                }
            }
        }
    }

    private func infoRow(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        colors: AppColors
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(colors.primary)
                .frame(width: 22)
            Text(title)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 36)
    }

    private var summaryLine: String {
        var parts = [
            Format.weekday(course.time.dayOfWeek),
            Format.periodRange(course.time.startNode, course.time.endNode),
        ]
        if let start = resolvedStart, let end = resolvedEnd {
            parts.append(Format.timeRange(start: start, end: end))
        }
        return parts.joined(separator: " · ")
    }

    private var resolvedStart: Date? {
        occurrenceClock(for: course, profile: store.timingProfile)?.start.date(on: .now)
    }

    private var resolvedEnd: Date? {
        occurrenceClock(for: course, profile: store.timingProfile)?.end.date(on: .now)
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
