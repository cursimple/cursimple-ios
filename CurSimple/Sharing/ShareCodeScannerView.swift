import CurSimpleCore
import SwiftUI
import VisionKit

/// Camera scanner for timetable share codes (QR). Falls back to a clear message
/// when the device cannot scan.
struct ShareCodeScannerView: View {

    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var errorMessage: String?

    private var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        let colors = AppColors.resolve(accent: .green, dark: colorScheme == .dark)

        ZStack {
            Color.black.ignoresSafeArea()

            if isSupported {
                ScannerRepresentable(
                    onCode: { code in
                        onCode(code)
                        dismiss()
                    },
                    onError: { message in
                        errorMessage = message
                    }
                )
                .ignoresSafeArea()

                overlay
            } else {
                unsupported(colors)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("common.cancel")
        }
    }

    private var overlay: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 240, height: 240)
            Spacer()
            Text("share.scan.hint")
                .appFont(13, weight: .medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.45)))
                .padding(.bottom, 40)
        }
    }

    private func unsupported(_ colors: AppColors) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .appFont(28)
                .foregroundStyle(.white)
            Text("share.scan.unsupported")
                .appFont(14, weight: .medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - VisionKit bridge

private struct ScannerRepresentable: UIViewControllerRepresentable {

    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !controller.isScanning else { return }
        do {
            try controller.startScanning()
        } catch {
            onError(error.localizedDescription)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        private let onCode: (String) -> Void
        private var handled = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !handled else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else { continue }
                // Only timetable share codes are accepted.
                guard payload.hasPrefix(ScheduleSharePayload.magicPrefix) else { continue }
                handled = true
                dataScanner.stopScanning()
                onCode(payload)
                return
            }
        }
    }
}
