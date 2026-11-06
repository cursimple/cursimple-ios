import Foundation

public enum AccentTheme: String, Codable, CaseIterable, Sendable, Identifiable {
    case teal
    case green
    case blue
    case purple
    case orange
    case pink

    public var id: String { rawValue }

    public var baseColor: RGBColor {
        switch self {
        case .teal: RGBColor(hex: "#2E8B9A")!
        case .green: RGBColor(hex: "#3FA277")!
        case .blue: RGBColor(hex: "#3F6FB5")!
        case .purple: RGBColor(hex: "#7259B5")!
        case .orange: RGBColor(hex: "#D0763B")!
        case .pink: RGBColor(hex: "#C25B7D")!
        }
    }

    public var localizationKey: String { "accent.\(rawValue)" }
}

public enum CoursePaletteStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard = "default"
    case morandi
    case macaron
    case vibrant
    case vintage

    public var id: String { rawValue }
    public var localizationKey: String { "palette.\(rawValue)" }
}

public struct CourseCardColors: Hashable, Sendable {
    public let fill: RGBColor
    public let border: RGBColor
    public let accent: RGBColor
    public let text: RGBColor
    public let secondaryText: RGBColor

    public init(fill: RGBColor, border: RGBColor, accent: RGBColor, text: RGBColor, secondaryText: RGBColor) {
        self.fill = fill
        self.border = border
        self.accent = accent
        self.text = text
        self.secondaryText = secondaryText
    }
}

public enum CoursePalette {

    /// Stable hue per course so colors do not change between launches.
    public static func hue(for course: CourseItem) -> Double {
        let seed = course.id.isEmpty ? course.title : course.id
        var hash: UInt32 = 2_166_136_261
        for byte in seed.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return Double(hash % 360)
    }

    public static func colors(
        for course: CourseItem,
        style: CoursePaletteStyle,
        dark: Bool
    ) -> CourseCardColors {
        let palette = styleParameters(style)
        let explicit = course.colorArgb.map { RGBColor(argb: $0) }
        let baseHue = explicit?.hsl.hue ?? hue(for: course)
        let saturation = explicit.map { min(max($0.hsl.saturation, 0.38), 0.82) } ?? palette.saturation
        let fillLightness = dark ? palette.darkFill : palette.lightFill
        let borderLightness = dark ? 0.68 : 0.52
        let accentLightness = dark ? 0.72 : 0.44

        let fill = RGBColor(hsl: HSL(hue: baseHue, saturation: saturation, lightness: fillLightness))
        let border = RGBColor(hsl: HSL(hue: baseHue, saturation: min(saturation + 0.08, 0.9), lightness: borderLightness))
        let accent = RGBColor(hsl: HSL(hue: baseHue, saturation: min(saturation + 0.12, 0.92), lightness: accentLightness))
        let text = dark
            ? RGBColor(hex: "#F2F5F7")!
            : RGBColor(hex: "#17232B")!
        let secondaryText = dark
            ? RGBColor(hex: "#C3CDD4")!
            : RGBColor(hex: "#41525E")!

        return CourseCardColors(
            fill: fill,
            border: border,
            accent: accent,
            text: text,
            secondaryText: secondaryText
        )
    }

    private static func styleParameters(
        _ style: CoursePaletteStyle
    ) -> (saturation: Double, lightFill: Double, darkFill: Double) {
        switch style {
        case .standard: (0.52, 0.92, 0.24)
        case .morandi: (0.26, 0.90, 0.28)
        case .macaron: (0.68, 0.93, 0.30)
        case .vibrant: (0.80, 0.88, 0.30)
        case .vintage: (0.38, 0.88, 0.24)
        }
    }

    /// Palette offered in the course editor; stored as explicit ARGB.
    public static let swatches: [UInt32] = [
        0xFF4F8DF7,
        0xFF34A853,
        0xFFF2994A,
        0xFFEB5757,
        0xFF9B51E0,
        0xFF2D9CDB,
        0xFFF2C94C,
        0xFF56CCF2,
    ]
}
