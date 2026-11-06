import Testing
@testable import CurSimpleCore

@Suite("Palette")
struct PaletteTests {

    @Test("Course hue is stable and in range")
    func stableHue() {
        let course = makeCourse(id: "stable-id")
        let first = CoursePalette.hue(for: course)
        let second = CoursePalette.hue(for: course)
        #expect(first == second)
        #expect((0..<360).contains(first))
    }

    @Test("Explicit course color keeps its hue")
    func explicitColor() {
        let raw: UInt32 = 0xFFEB5757
        let course = makeCourse(id: "a", colorArgb: raw)
        let expectedHue = RGBColor(argb: raw).hsl.hue

        for dark in [false, true] {
            let colors = CoursePalette.colors(for: course, style: .standard, dark: dark)
            #expect(abs(colors.accent.hsl.hue - expectedHue) < 1)
            #expect(abs(colors.fill.hsl.hue - expectedHue) < 1)
        }
    }

    @Test("Light fills are lighter than dark fills")
    func lightness() {
        let course = makeCourse(id: "a")
        let light = CoursePalette.colors(for: course, style: .standard, dark: false)
        let dark = CoursePalette.colors(for: course, style: .standard, dark: true)
        #expect(light.fill.hsl.lightness > dark.fill.hsl.lightness)
    }

    @Test("Color round trips through ARGB and hex")
    func colorRoundTrip() {
        let original = RGBColor(hex: "#2E8B9A")!
        #expect(original.hex == "#2E8B9A")
        #expect(RGBColor(argb: original.argb).hex == "#2E8B9A")
        #expect(RGBColor(hex: "#GGGGGG") == nil)
    }

    @Test("Accent presets are all distinct")
    func accentsDistinct() {
        let hexes = Set(AccentTheme.allCases.map(\.baseColor.hex))
        #expect(hexes.count == AccentTheme.allCases.count)
    }
}
