import SwiftUI
import UIKit

/// Typography that follows the system text size.
///
/// The week grid keeps fixed sizes because its geometry is computed from row
/// heights; list, form and sheet screens use `.appFont` so larger accessibility
/// sizes stay readable.
struct AppFontModifier: ViewModifier {

    @Environment(\.dynamicTypeSize) private var typeSize

    let size: CGFloat
    let weight: Font.Weight
    let style: Font.TextStyle

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight))
    }

    private var scaledSize: CGFloat {
        let metrics = UIFontMetrics(forTextStyle: style.uiTextStyle)
        let traits = UITraitCollection(preferredContentSizeCategory: typeSize.uiContentSizeCategory)
        // Keep dense layouts sane: never shrink below the design size.
        return max(size, metrics.scaledValue(for: size, compatibleWith: traits))
    }
}

extension View {

    /// System font at `size` that scales with Dynamic Type.
    func appFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        style: Font.TextStyle = .body
    ) -> some View {
        modifier(AppFontModifier(size: size, weight: weight, style: style))
    }

    /// Cap scaling so dense layouts stay readable without breaking.
    func appDynamicType() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}


private extension DynamicTypeSize {
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}


extension Text {

    /// Dynamic-Type aware font for text nodes, so `.appFont` works without a
    /// wrapping view modifier.
    func appFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        style: Font.TextStyle = .body
    ) -> Text {
        font(.system(size: AppFontScaling.size(size, style: style), weight: weight))
    }
}

/// Shared scaling so view, text and image variants agree.
enum AppFontScaling {

    static func size(_ size: CGFloat, style: Font.TextStyle) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: style.uiTextStyle)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory.current)
        return max(size, metrics.scaledValue(for: size, compatibleWith: traits))
    }
}

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

private extension UIContentSizeCategory {
    static var current: UIContentSizeCategory {
        UIApplication.shared.preferredContentSizeCategory
    }
}
