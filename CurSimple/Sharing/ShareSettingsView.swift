import CoreImage
import CurSimpleCore
import SwiftUI
import UIKit

struct ShareSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var codeSheet: ShareCodePayload?
    @State private var importText = ""
    @State private var importError: String?
    @State private var preview: ImportPreviewData?
    @State private var errorMessage: String?
    @State private var imagePreview: UIImage?

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "share.pageTitle", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        exportCard(colors: colors)
                        imageCard(colors: colors)
                        importCard(colors: colors)
                        infoCard(colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-importFixture") {
                importText = SampleData.shareFixtureCode() ?? ""
            }
            if arguments.contains("-openShareCode") {
                generateCode()
            }
            if arguments.contains("-openShareImage") {
                exportImage()
            }
            if arguments.contains("-openImportPreview") {
                parseCode()
            }
        }
        .sheet(item: $codeSheet) { payload in
            ShareCodeSheet(payload: payload)
                .presentationDetents([.large])
        }
        .sheet(item: $preview) { preview in
            ImportPreviewSheet(preview: preview) {
                applyImport(preview)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Cards

    private func exportCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "share.export.title", colors: colors)

            SettingsCard(colors: colors) {
                Text("share.export.footer")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: generateCode) {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("share.export.action")
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
    }

    private func imageCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "share.image.title", colors: colors)

            SettingsCard(colors: colors) {
                Text("share.image.footer")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: exportImage) {
                    HStack {
                        Image(systemName: "photo")
                        Text("share.image.action")
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                if let imagePreview {
                    Image(uiImage: imagePreview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 10)

                    ShareLink(
                        item: ScheduleImageTransfer(image: imagePreview),
                        preview: SharePreview("share.image.title", image: Image(uiImage: imagePreview))
                    ) {
                        Text("share.image.share")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(colors.primary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .overlay(Capsule().stroke(colors.primary.opacity(0.5), lineWidth: 1))
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func importCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "share.import.title", colors: colors)

            SettingsCard(colors: colors) {
                TextEditor(text: $importText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(colors.onSurface)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110, maxHeight: 160)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colors.surfaceVariant.opacity(0.6))
                    )
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text("share.import.placeholder")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(colors.onSurfaceVariant)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                if let importError {
                    Text(importError)
                        .font(AppFont.label)
                        .foregroundStyle(colors.error)
                        .padding(.top, 6)
                }

                HStack(spacing: 10) {
                    Button {
                        if let string = UIPasteboard.general.string {
                            importText = string
                            importError = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                            Text("share.import.paste")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colors.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Capsule().stroke(colors.primary.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: parseCode) {
                        Text("share.import.action")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(colors.onPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Capsule().fill(colors.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(.top, 8)
            }
        }
    }

    private func infoCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text("share.info")
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func exportImage() {
        guard let term = store.activeTerm else { return }
        let weekStart = ScheduleCalendar.startOfDisplayWeek(
            containing: .now,
            weekStart: store.preferences.weekStart
        )
        let week = term.startDateValue.map {
            displayWeekTermIndex(termStart: $0, displayWeekStart: weekStart)
        } ?? 0
        imagePreview = ScheduleImageRenderer.render(
            term: term,
            profile: store.timingProfile,
            preferences: store.preferences,
            holidayCalendar: store.state.holidayCalendar,
            overrides: store.state.overrides,
            weekStart: weekStart,
            weekNumber: week,
            dark: colorScheme == .dark
        )
        if imagePreview == nil {
            errorMessage = String(localized: "share.image.failed")
        }
    }

    private func generateCode() {
        guard let term = store.activeTerm else { return }
        let payload = makeSharePayload(term: term, profile: store.timingProfile)
        guard let code = try? ShareCodec.encode(payload) else { return }
        codeSheet = ShareCodePayload(
            code: code,
            termName: term.name,
            courseCount: term.courses.filter { !$0.hidden }.count
        )
    }

    private func parseCode() {
        importError = nil
        do {
            let payload = try ShareCodec.decode(importText)
            guard let imported = importedTimetable(
                from: payload,
                fallbackName: String(localized: "share.importedName")
            ) else {
                importError = String(localized: "share.import.invalid")
                return
            }
            preview = ImportPreviewData(
                payload: payload,
                imported: imported,
                code: importText
            )
        } catch {
            importError = String(localized: "share.import.invalid")
        }
    }

    private func applyImport(_ preview: ImportPreviewData) {
        if !preview.imported.timingSlots.isEmpty,
           preview.imported.timingSlots != store.timingProfile.slots {
            let profile = TimingProfile(
                id: "shared-\(UUID().uuidString)",
                name: String(localized: "share.importedProfileName"),
                slots: preview.imported.timingSlots,
                timezone: TimeZone.current.identifier
            )
            store.updateTimingProfile(profile)
        }
        store.addTerm(preview.imported.term)
        importText = ""
        self.preview = nil
        dismiss()
    }
}

// MARK: - Share sheet

struct ShareCodePayload: Identifiable {
    let id = UUID()
    let code: String
    let termName: String
    let courseCount: Int
}

private struct ShareCodeSheet: View {

    let payload: ShareCodePayload

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var copied = false
    @Environment(AppStore.self) private var store

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("share.code.title")
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
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text(payload.termName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(colors.onSurface)
                        Text(String(format: String(localized: "share.code.summary"), payload.courseCount))
                            .font(AppFont.bodySmall)
                            .foregroundStyle(colors.onSurfaceVariant)

                        if payload.code.utf8.count <= 2200 {
                            QRCodeView(text: payload.code)
                                .frame(width: 220, height: 220)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.white)
                                )
                        } else {
                            Text("share.code.tooLongForQR")
                                .font(AppFont.label)
                                .foregroundStyle(colors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                        }

                        Text(payload.code)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(colors.onSurfaceVariant)
                            .textSelection(.enabled)
                            .lineLimit(6)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(colors.surface)
                            )

                        HStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = payload.code
                                copied = true
                            } label: {
                                Label(
                                    copied ? "share.code.copied" : "share.code.copy",
                                    systemImage: copied ? "checkmark" : "doc.on.doc"
                                )
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(colors.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(colors.primary))
                            }
                            .buttonStyle(.plain)

                            ShareLink(item: payload.code) {
                                Label("share.code.share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(colors.primary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Capsule().stroke(colors.primary.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - QR code

private struct QRCodeView: View {

    let text: String

    var body: some View {
        if let image = Self.makeImage(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }

    private static func makeImage(_ text: String) -> UIImage? {
        guard let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Import preview

struct ImportPreviewData: Identifiable {
    let id = UUID()
    let payload: ScheduleSharePayload
    let imported: ImportedTimetable
    let code: String
}

private struct ImportPreviewSheet: View {

    let preview: ImportPreviewData
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStore.self) private var store

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("share.preview.title")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.onBackground)
                    HStack {
                        Button("common.cancel") { dismiss() }
                            .font(.system(size: 14))
                            .foregroundStyle(colors.primary)
                        Spacer()
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsCard(colors: colors) {
                            row("share.preview.term", value: preview.imported.term.name, colors: colors)
                            Divider().overlay(colors.outlineVariant).padding(.vertical, 3)
                            row(
                                "share.preview.start",
                                value: preview.imported.term.startDate,
                                colors: colors
                            )
                            Divider().overlay(colors.outlineVariant).padding(.vertical, 3)
                            row(
                                "share.preview.courses",
                                value: String(
                                    format: String(localized: "share.preview.coursesValue"),
                                    preview.imported.term.courses.count
                                ),
                                colors: colors
                            )
                            Divider().overlay(colors.outlineVariant).padding(.vertical, 3)
                            row(
                                "share.preview.timing",
                                value: String(
                                    format: String(localized: "share.preview.timingValue"),
                                    preview.imported.timingSlots.count
                                ),
                                colors: colors
                            )
                        }

                        Text("share.preview.warning")
                            .font(AppFont.label)
                            .foregroundStyle(colors.onSurfaceVariant)
                            .padding(.horizontal, 4)

                        Button(action: onConfirm) {
                            Text("share.preview.confirm")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(colors.onPrimary)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(Capsule().fill(colors.primary))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func row(_ label: LocalizedStringKey, value: String, colors: AppColors) -> some View {
        HStack {
            Text(label)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colors.onSurface)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 36)
    }
}


/// Wraps a rendered timetable so it can be shared as a PNG file.
struct ScheduleImageTransfer: Transferable {

    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.image.pngData() ?? Data()
        }
        .suggestedFileName("cursimple-timetable.png")
    }
}
