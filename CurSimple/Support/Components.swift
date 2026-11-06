import SwiftUI

struct CircleIconButton: View {

    let systemImage: String
    let label: LocalizedStringKey
    var tint: Color?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(
        systemImage: String,
        label: LocalizedStringKey,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint ?? Color.primary)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: AppMetrics.touchTarget, height: AppMetrics.touchTarget)
        .accessibilityLabel(label)
    }
}

enum PillButtonRole {
    case primary
    case secondary
    case destructive
}

struct PillButton: View {

    let title: LocalizedStringKey
    var role: PillButtonRole = .primary
    var systemImage: String?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 16)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
            .overlay {
                if role == .secondary {
                    Capsule().stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                }
                if role == .destructive {
                    Capsule().stroke(Color.red.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch role {
        case .primary: .white
        case .secondary: .accentColor
        case .destructive: .red
        }
    }

    private var background: Color {
        switch role {
        case .primary: .accentColor
        case .secondary: .clear
        case .destructive: .clear
        }
    }
}

struct EmptyStateView: View {

    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10)))

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 42)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct InfoRow: View {

    let systemImage: String
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ConflictBanner: View {

    let message: String
    var hint: LocalizedStringKey? = "course.conflict.hint"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("course.conflict.title")
                    .font(.footnote.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}
