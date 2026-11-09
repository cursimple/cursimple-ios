import CurSimpleCore
import SwiftUI

/// Grid appearance controls: text size, card height, corners, opacity, grid
/// lines and which details appear on cards.
struct DisplaySettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let display = store.preferences.display

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "settings.display", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        previewCard(display, colors: colors)
                        sizeCard(display, colors: colors)
                        gridCard(display, colors: colors)
                        detailCard(display, colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Cards

    private func previewCard(_ display: ScheduleDisplayPreferences, colors: AppColors) -> some View {
        let entry = CoursePalette.entries(for: store.preferences.paletteStyle, dark: colorScheme == .dark)[0]
        return VStack(alignment: .leading, spacing: 0) {
            Text("display.preview")
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("高等数学")
                    .font(.system(size: CGFloat(display.textSize), weight: .semibold))
                    .foregroundStyle(entry.onContainer.color)
                Text("@教学楼-A201")
                    .font(.system(size: CGFloat(max(display.textSize - 3, 8))))
                    .foregroundStyle(entry.onContainer.color.opacity(0.72))
                if display.showTeacherInGrid {
                    Text("张老师")
                        .font(.system(size: CGFloat(max(display.textSize - 3, 8))))
                        .foregroundStyle(entry.onContainer.color.opacity(0.72))
                }
            }
            .padding(5)
            .frame(
                maxWidth: .infinity,
                minHeight: CGFloat(display.cardHeight),
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(cornerRadius: CGFloat(display.cornerRadius), style: .continuous)
                    .fill(entry.container.color.opacity(display.cardOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(display.cornerRadius), style: .continuous)
                    .strokeBorder(gridBorderColor(display, colors: colors), style: gridStroke(display))
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func sizeCard(_ display: ScheduleDisplayPreferences, colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            sliderRow(
                "display.textSize",
                value: "\(display.textSize)",
                binding: .constant(Double(display.textSize)),
                range: textSizeRange,
                colors: colors
            ) { value in
                update { $0.textSize = ScheduleDisplayPreferences.coerceTextSize(Int(value.rounded())) }
            }

            Divider().overlay(colors.outlineVariant).padding(.vertical, 4)

            sliderRow(
                "display.cardHeight",
                value: "\(display.cardHeight)",
                binding: .constant(Double(display.cardHeight)),
                range: cardHeightRange,
                colors: colors
            ) { value in
                update { $0.cardHeight = ScheduleDisplayPreferences.coerceCardHeight(Int(value.rounded())) }
            }

            Divider().overlay(colors.outlineVariant).padding(.vertical, 4)

            sliderRow(
                "display.cornerRadius",
                value: "\(display.cornerRadius)",
                binding: .constant(Double(display.cornerRadius)),
                range: radiusRange,
                colors: colors
            ) { value in
                update { $0.cornerRadius = ScheduleDisplayPreferences.coerceRadius(Int(value.rounded())) }
            }

            Divider().overlay(colors.outlineVariant).padding(.vertical, 4)

            sliderRow(
                "display.opacity",
                value: "\(display.backgroundOpacity)%",
                binding: .constant(Double(display.backgroundOpacity)),
                range: 0...100,
                colors: colors
            ) { value in
                update { $0.backgroundOpacity = ScheduleDisplayPreferences.coerceOpacity(Int(value.rounded())) }
            }
        }
    }

    private func sliderRow(
        _ title: LocalizedStringKey,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        colors: AppColors,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.primary)
            }
            Slider(
                value: Binding(
                    get: { binding.wrappedValue },
                    set: { onChange($0) }
                ),
                in: range
            )
            .tint(colors.primary)
        }
        .padding(.vertical, 4)
    }

    private func gridCard(_ display: ScheduleDisplayPreferences, colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "display.gridSection", colors: colors)

            SettingsCard(colors: colors) {
                HStack(spacing: 8) {
                    ForEach(ScheduleDisplayPreferences.GridStyle.allCases) { style in
                        let selected = display.gridStyle == style
                        Button {
                            update { $0.gridStyle = style }
                        } label: {
                            Text(LocalizedStringKey(style.localizationKey))
                                .appFont(13, weight: .medium)
                                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected ? colors.primary : colors.surfaceVariant)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func detailCard(_ display: ScheduleDisplayPreferences, colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Toggle(isOn: Binding(
                get: { display.showTeacherInGrid },
                set: { value in update { $0.showTeacherInGrid = value } }
            )) {
                Text("display.showTeacher")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
            }
            .tint(colors.primary)

            Divider().overlay(colors.outlineVariant).padding(.vertical, 6)

            Toggle(isOn: Binding(
                get: { display.dimInactiveCourses },
                set: { value in update { $0.dimInactiveCourses = value } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("display.dimInactive")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Text("display.dimInactive.footer")
                        .font(AppFont.label)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
            }
            .tint(colors.primary)
        }
    }

    // MARK: - Helpers

    private var textSizeRange: ClosedRange<Double> {
        let lower = Double(ScheduleDisplayPreferences.textSizeRange.lowerBound)
        let upper = Double(ScheduleDisplayPreferences.textSizeRange.upperBound)
        return lower...upper
    }

    private var cardHeightRange: ClosedRange<Double> {
        let lower = Double(ScheduleDisplayPreferences.cardHeightRange.lowerBound)
        let upper = Double(ScheduleDisplayPreferences.cardHeightRange.upperBound)
        return lower...upper
    }

    private var radiusRange: ClosedRange<Double> {
        let lower = Double(ScheduleDisplayPreferences.radiusRange.lowerBound)
        let upper = Double(ScheduleDisplayPreferences.radiusRange.upperBound)
        return lower...upper
    }

    private func gridBorderColor(_ display: ScheduleDisplayPreferences, colors: AppColors) -> Color {
        display.gridStyle == .none ? .clear : colors.outlineVariant
    }

    private func gridStroke(_ display: ScheduleDisplayPreferences) -> StrokeStyle {
        switch display.gridStyle {
        case .solid: StrokeStyle(lineWidth: 1)
        case .dashed: StrokeStyle(lineWidth: 1, dash: [4, 3])
        case .none: StrokeStyle(lineWidth: 0)
        }
    }

    private func update(_ transform: (inout ScheduleDisplayPreferences) -> Void) {
        var preferences = store.preferences
        var display = preferences.display
        transform(&display)
        preferences.display = display.normalized
        store.setPreferences(preferences)
    }
}
