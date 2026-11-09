import CurSimpleCore
import SwiftUI
import UniformTypeIdentifiers

/// Export the whole local database and restore it from a backup file.
struct BackupSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingRestore: (payload: BackupPayload, summary: BackupSummary)?
    @State private var errorMessage: String?
    @State private var restored = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "backup.pageTitle", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryCard(colors: colors)
                        exportCard(colors: colors)
                        importCard(colors: colors)
                        warningCard(colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: backupFileName()
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("backup.restoreTitle", isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )) {
            Button("common.cancel", role: .cancel) { pendingRestore = nil }
            Button("backup.restore", role: .destructive) {
                if let pending = pendingRestore {
                    store.replaceState(restoredState(from: pending.payload))
                    restored = true
                }
                pendingRestore = nil
            }
        } message: {
            if let pending = pendingRestore {
                Text(String(
                    format: String(localized: "backup.restoreMessage"),
                    pending.summary.termCount,
                    pending.summary.courseCount,
                    pending.summary.memoCount
                ))
            }
        }
        .alert("backup.errorTitle", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.done", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if restored {
                Text("backup.restored")
                    .appFont(13, weight: .medium)
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Capsule().fill(colors.primary))
                    .padding(.bottom, 20)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            restored = false
                        }
                    }
            }
        }
    }

    // MARK: - Cards

    private func summaryCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack(spacing: 12) {
                stat(value: store.state.terms.count, label: "backup.stat.terms", colors: colors)
                divider(colors)
                stat(value: totalCourses, label: "backup.stat.courses", colors: colors)
                divider(colors)
                stat(value: store.state.memos.count, label: "backup.stat.memos", colors: colors)
            }
        }
    }

    private func stat(value: Int, label: LocalizedStringKey, colors: AppColors) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .appFont(20, weight: .bold)
                .foregroundStyle(colors.primary)
            Text(label)
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    private func divider(_ colors: AppColors) -> some View {
        Rectangle()
            .fill(colors.outlineVariant)
            .frame(width: 1, height: 30)
    }

    private func exportCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "backup.export", colors: colors)

            SettingsCard(colors: colors) {
                Text("backup.export.footer")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: exportBackup) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("backup.export.action")
                        Spacer()
                    }
                    .appFont(13, weight: .semibold)
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

    private func importCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "backup.import", colors: colors)

            SettingsCard(colors: colors) {
                Text("backup.import.footer")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("backup.import.action")
                        Spacer()
                    }
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(colors.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Capsule().stroke(colors.primary.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
    }

    private func warningCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .appFont(12)
                    .foregroundStyle(colors.error)
                Text("backup.warning")
                    .font(AppFont.label)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private var totalCourses: Int {
        store.state.terms.reduce(0) { $0 + $1.courses.count }
    }

    private func exportBackup() {
        let payload = makeBackup(
            state: store.state,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        )
        guard let data = try? encodeBackup(payload) else {
            errorMessage = String(localized: "backup.error.export")
            return
        }
        exportDocument = BackupDocument(data: data)
        showExporter = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let payload = try decodeBackup(data)
                pendingRestore = (payload, backupSummary(payload))
            } catch {
                errorMessage = String(localized: "backup.error.import")
            }
        }
    }
}

/// Minimal `FileDocument` wrapper for the JSON backup.
struct BackupDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
