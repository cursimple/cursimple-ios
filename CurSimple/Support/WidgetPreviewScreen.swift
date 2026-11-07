#if DEBUG
import CurSimpleCore
import SwiftUI
import WidgetKit

/// Debug-only surface that renders the widget views at their real sizes.
/// Home-screen placement cannot be automated in the simulator, so this is how
/// the widget layout is visually verified.
struct WidgetPreviewScreen: View {

    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    private var morningMoment: Date {
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: 8 * 60 + 50, to: start) ?? start
    }

    private var preClassMoment: Date {
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: 7 * 60 + 40, to: start) ?? start
    }

    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.957, green: 0.973, blue: 0.957, opacity: 1)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    Text("Widget Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    label("今日 · 中")
                    widgetCard(width: 329, height: 155) {
                        TodayWidgetView(
                            snapshot: .preview,
                            day: WidgetSnapshot.preview.today,
                            date: morningMoment,
                            family: .systemMedium
                        )
                    }

                    label("下一节 · 中")
                    widgetCard(width: 329, height: 155) {
                        NextWidgetView(
                            snapshot: .preview,
                            date: preClassMoment,
                            family: .systemMedium
                        )
                    }

                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 8) {
                            label("今日 · 小")
                            widgetCard(width: 155, height: 155) {
                                TodayWidgetView(
                                    snapshot: .preview,
                                    day: WidgetSnapshot.preview.today,
                                    date: morningMoment,
                                    family: .systemSmall
                                )
                            }
                        }

                        VStack(spacing: 8) {
                            label("下一节 · 小")
                            widgetCard(width: 155, height: 155) {
                                NextWidgetView(
                                    snapshot: .preview,
                                    date: preClassMoment,
                                    family: .systemSmall
                                )
                            }
                        }
                    }

                    label("今日 · 大")
                    widgetCard(width: 329, height: 345) {
                        TodayWidgetView(
                            snapshot: .preview,
                            day: WidgetSnapshot.preview.today,
                            date: morningMoment,
                            family: .systemLarge
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func widgetCard<Content: View>(
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: width, height: height)
            .background(WidgetSurface.background(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}
#endif
