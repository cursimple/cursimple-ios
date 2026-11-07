import Foundation

public enum AccentTheme: String, Codable, CaseIterable, Sendable, Identifiable {
    case green
    case blue
    case purple
    case orange
    case pink

    public var id: String { rawValue }

    public var baseColor: RGBColor {
        switch self {
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

/// Fill and content colors for one course card.
public struct CoursePaletteEntry: Hashable, Sendable {
    public let container: RGBColor
    public let onContainer: RGBColor

    public init(container: RGBColor, onContainer: RGBColor) {
        self.container = container
        self.onContainer = onContainer
    }
}

public enum CoursePalette {

    /// Same seed and index as the existing palette: stable per course title.
    public static func courseEntry(
        for course: CourseItem,
        style: CoursePaletteStyle,
        dark: Bool
    ) -> CoursePaletteEntry {
        if course.category == .exam {
            return examEntry(dark: dark)
        }
        if course.category == .event {
            return eventEntry(dark: dark)
        }
        if let argb = course.colorArgb {
            let container = RGBColor(argb: argb)
            return CoursePaletteEntry(container: container, onContainer: readableOn(container))
        }
        let palette = entries(for: style, dark: dark)
        guard !palette.isEmpty else {
            return CoursePaletteEntry(
                container: dark ? RGBColor(hex: "#26332B")! : RGBColor(hex: "#E2EEE3")!,
                onContainer: dark ? RGBColor(hex: "#E2EBE5")! : RGBColor(hex: "#1F2A24")!
            )
        }
        let index = paletteIndex(forSeed: course.title, count: palette.count)
        return palette[index]
    }

    /// Events share the warm neutral card, matching the shared event color.
    public static func eventEntry(dark: Bool) -> CoursePaletteEntry {
        dark
            ? CoursePaletteEntry(container: RGBColor(hex: "#4D3F1A")!, onContainer: RGBColor(hex: "#EFD795")!)
            : CoursePaletteEntry(container: RGBColor(hex: "#FBEFCE")!, onContainer: RGBColor(hex: "#7E5B14")!)
    }

    public static func examEntry(dark: Bool) -> CoursePaletteEntry {
        dark
            ? CoursePaletteEntry(container: RGBColor(hex: "#4A241B")!, onContainer: RGBColor(hex: "#F1B8AC")!)
            : CoursePaletteEntry(container: RGBColor(hex: "#FDE7E3")!, onContainer: RGBColor(hex: "#8E2410")!)
    }

    /// Kotlin/Java `String.hashCode()` followed by `Int.mod(count)`.
    public static func paletteIndex(forSeed seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: Int32 = 0
        for unit in seed.utf16 {
            hash = 31 &* hash &+ Int32(bitPattern: UInt32(unit))
        }
        let remainder = hash % Int32(count)
        return Int(remainder < 0 ? remainder + Int32(count) : remainder)
    }

    /// Relative luminance, matching Compose's `Color.luminance()` threshold.
    public static func readableOn(_ color: RGBColor) -> RGBColor {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(color.red)
            + 0.7152 * linear(color.green)
            + 0.0722 * linear(color.blue)
        return luminance > 0.5
            ? RGBColor(hex: "#1F2A24")!
            : RGBColor(hex: "#FFFFFF")!
    }

    public static func entries(for style: CoursePaletteStyle, dark: Bool) -> [CoursePaletteEntry] {
        let pairs: [(String, String)]
        switch (style, dark) {
        case (.standard, false):
            pairs = [
                ("#DDEBFA", "#2C5587"), ("#DCEFD7", "#325E2A"), ("#FBE0E4", "#872E48"),
                ("#E5DEF6", "#4F388B"), ("#FBEFCE", "#7E5B14"), ("#D5EBE6", "#1F5C50"),
                ("#FBE0CB", "#8C4A1F"),
            ]
        case (.standard, true):
            pairs = [
                ("#243A52", "#B5D3F0"), ("#263F23", "#B8DDB1"), ("#4A2B33", "#F1B8C2"),
                ("#3A2F58", "#CFC2EE"), ("#4D3F1A", "#EFD795"), ("#1F3A36", "#A8D7CC"),
                ("#4A3220", "#F4C49E"),
            ]
        case (.morandi, false):
            pairs = [
                ("#E8D7D8", "#5D4042"), ("#D8E2DC", "#3E5246"), ("#D5DDE5", "#38495C"),
                ("#EBE3D5", "#5C4E38"), ("#DDD5E0", "#4E4054"), ("#E5DDD8", "#59483F"),
                ("#DFE3D5", "#48523A"),
            ]
        case (.morandi, true):
            pairs = [
                ("#3E2C2E", "#E2B8BB"), ("#2C3932", "#BDCEBF"), ("#293542", "#B8C8D9"),
                ("#3D3629", "#DED0B9"), ("#362C3B", "#D1BED8"), ("#3B3029", "#D6BEB2"),
                ("#2F3628", "#C5CEA8"),
            ]
        case (.macaron, false):
            pairs = [
                ("#FCE4EC", "#880E4F"), ("#E8F5E9", "#1B5E20"), ("#FFF9C4", "#826200"),
                ("#E1F5FE", "#01579B"), ("#F3E5F5", "#4A148C"), ("#FFE0B2", "#943800"),
                ("#E0F2F1", "#004D40"),
            ]
        case (.macaron, true):
            pairs = [
                ("#4A1528", "#F8BBD0"), ("#1B3B22", "#C8E6C9"), ("#453B12", "#FFF59D"),
                ("#123851", "#B3E5FC"), ("#38194D", "#E1BEE7"), ("#4D2712", "#FFCC80"),
                ("#123D38", "#80CBC4"),
            ]
        case (.vibrant, false):
            pairs = [
                ("#FEF08A", "#854D0E"), ("#FED7AA", "#9A3412"), ("#BAE6FD", "#0369A1"),
                ("#A7F3D0", "#065F46"), ("#FBCFE8", "#9D174D"), ("#DDD6FE", "#5B21B6"),
                ("#D9F99D", "#3F6212"),
            ]
        case (.vibrant, true):
            pairs = [
                ("#594200", "#FEF08A"), ("#5C2009", "#FFC4A1"), ("#083F66", "#7DD3FC"),
                ("#064E3B", "#6EE7B7"), ("#5E1236", "#F472B6"), ("#3B1C7A", "#C4B5FD"),
                ("#2A4505", "#BEF264"),
            ]
        case (.vintage, false):
            pairs = [
                ("#F5E6D3", "#6D3814"), ("#E5E8D8", "#434D2E"), ("#F2DDD5", "#743627"),
                ("#E8DFD8", "#523F35"), ("#DCE3EB", "#2F435E"), ("#EDE6D0", "#5B4F1F"),
                ("#E4DCE4", "#4B344D"),
            ]
        case (.vintage, true):
            pairs = [
                ("#4A2A14", "#EDCFB1"), ("#2D3520", "#CBD3B2"), ("#4A241B", "#E8B8AC"),
                ("#382C26", "#D4C2B8"), ("#212E3F", "#B7C7DC"), ("#3B3419", "#DCD0A8"),
                ("#332335", "#D1BFD2"),
            ]
        }
        return pairs.map { CoursePaletteEntry(container: RGBColor(hex: $0.0)!, onContainer: RGBColor(hex: $0.1)!) }
    }

    /// Swatches offered when a course should have an explicit color.
    public static func swatches(for style: CoursePaletteStyle, dark: Bool) -> [UInt32] {
        entries(for: style, dark: dark).map(\.container.argb)
    }
}
