#if DEBUG
import CurSimpleCore
import SwiftUI
import WidgetKit

/// Debug-only surface that renders the widget views at their real sizes.
/// Home-screen placement cannot be automated in the simulator, so this is how
/// the widget layout is visually verified.
struct WidgetPreviewScreen: View {

    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.957, green: 0.973, blue: 0.957, opacity: 1)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Widget Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                widgetCard(family: .systemMedium, size: CGSize(width: 329, height: 155))
                widgetCard(family: .systemSmall, size: CGSize(width: 155, height: 155))
            }
        }
    }

    private func widgetCard(family: WidgetFamily, size: CGSize) -> some View {
        TodayWidgetView(
            snapshot: .preview,
            date: .now,
            family: family
        )
        .frame(width: size.width, height: size.height)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}
#endif
