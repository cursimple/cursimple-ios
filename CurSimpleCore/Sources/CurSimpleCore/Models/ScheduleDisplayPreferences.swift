import Foundation

/// Grid appearance knobs exposed in Settings → Display.
public struct ScheduleDisplayPreferences: Codable, Hashable, Sendable {

    public enum GridStyle: String, Codable, CaseIterable, Sendable, Identifiable {
        case solid
        case dashed
        case none

        public var id: String { rawValue }
        public var localizationKey: String { "display.grid.\(rawValue)" }
    }

    /// Course title size in points.
    public var textSize: Int
    /// Minimum course card height in points.
    public var cardHeight: Int
    public var cornerRadius: Int
    /// 0...100; 0 keeps cards fully opaque.
    public var backgroundOpacity: Int
    public var gridStyle: GridStyle
    /// Inactive (not this week) courses fade out.
    public var dimInactiveCourses: Bool
    /// Show teacher names inside week cards.
    public var showTeacherInGrid: Bool

    public init(
        textSize: Int = 12,
        cardHeight: Int = 64,
        cornerRadius: Int = 10,
        backgroundOpacity: Int = 0,
        gridStyle: GridStyle = .solid,
        dimInactiveCourses: Bool = true,
        showTeacherInGrid: Bool = false
    ) {
        self.textSize = textSize
        self.cardHeight = cardHeight
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.gridStyle = gridStyle
        self.dimInactiveCourses = dimInactiveCourses
        self.showTeacherInGrid = showTeacherInGrid
    }

    private enum CodingKeys: String, CodingKey {
        case textSize, cardHeight, cornerRadius, backgroundOpacity, gridStyle
        case dimInactiveCourses, showTeacherInGrid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ScheduleDisplayPreferences()
        textSize = Self.coerceTextSize(
            try container.decodeIfPresent(Int.self, forKey: .textSize) ?? defaults.textSize
        )
        cardHeight = Self.coerceCardHeight(
            try container.decodeIfPresent(Int.self, forKey: .cardHeight) ?? defaults.cardHeight
        )
        cornerRadius = Self.coerceRadius(
            try container.decodeIfPresent(Int.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        )
        backgroundOpacity = Self.coerceOpacity(
            try container.decodeIfPresent(Int.self, forKey: .backgroundOpacity) ?? defaults.backgroundOpacity
        )
        gridStyle = (try? container.decodeIfPresent(GridStyle.self, forKey: .gridStyle)) ?? defaults.gridStyle
        dimInactiveCourses = try container.decodeIfPresent(Bool.self, forKey: .dimInactiveCourses)
            ?? defaults.dimInactiveCourses
        showTeacherInGrid = try container.decodeIfPresent(Bool.self, forKey: .showTeacherInGrid)
            ?? defaults.showTeacherInGrid
    }

    public static let textSizeRange = 9...18
    public static let cardHeightRange = 48...110
    public static let radiusRange = 0...20

    public static func coerceTextSize(_ value: Int) -> Int {
        min(max(value, textSizeRange.lowerBound), textSizeRange.upperBound)
    }

    public static func coerceCardHeight(_ value: Int) -> Int {
        min(max(value, cardHeightRange.lowerBound), cardHeightRange.upperBound)
    }

    public static func coerceRadius(_ value: Int) -> Int {
        min(max(value, radiusRange.lowerBound), radiusRange.upperBound)
    }

    public static func coerceOpacity(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    public var normalized: ScheduleDisplayPreferences {
        var copy = self
        copy.textSize = Self.coerceTextSize(textSize)
        copy.cardHeight = Self.coerceCardHeight(cardHeight)
        copy.cornerRadius = Self.coerceRadius(cornerRadius)
        copy.backgroundOpacity = Self.coerceOpacity(backgroundOpacity)
        return copy
    }

    public var cardOpacity: Double {
        1 - Double(backgroundOpacity) / 100 * 0.7
    }
}
