import Testing
@testable import CurSimpleCore

@Suite("Palette")
struct PaletteTests {

    @Test("Kotlin string hash picks the same palette slot")
    func kotlinHashIndex() {
        // "abc".hashCode() == 96354; 96354 mod 7 == 6.
        #expect(CoursePalette.paletteIndex(forSeed: "abc", count: 7) == 6)
        #expect(CoursePalette.paletteIndex(forSeed: "高等数学", count: 7) >= 0)
        #expect(CoursePalette.paletteIndex(forSeed: "高等数学", count: 7) < 7)
    }

    @Test("Index is stable for the same course title")
    func stableIndex() {
        let first = CoursePalette.paletteIndex(forSeed: "数据结构", count: 7)
        let second = CoursePalette.paletteIndex(forSeed: "数据结构", count: 7)
        #expect(first == second)
    }

    @Test("Course entry follows the Android palette")
    func entryMatchesPalette() {
        let palette = CoursePalette.entries(for: .standard, dark: false)
        #expect(palette.count == 7)
        let course = makeCourse(id: "a", title: "abc")
        let index = CoursePalette.paletteIndex(forSeed: "abc", count: palette.count)
        let entry = CoursePalette.courseEntry(for: course, style: .standard, dark: false)
        #expect(entry == palette[index])
    }

    @Test("Every palette style has seven entries in both modes")
    func styleSizes() {
        for style in CoursePaletteStyle.allCases {
            #expect(CoursePalette.entries(for: style, dark: false).count == 7)
            #expect(CoursePalette.entries(for: style, dark: true).count == 7)
        }
    }

    @Test("Explicit color keeps the chosen fill")
    func explicitColor() {
        let raw: UInt32 = 0xFFEB5757
        let course = makeCourse(id: "a", colorArgb: raw)
        let entry = CoursePalette.courseEntry(for: course, style: .standard, dark: false)
        #expect(entry.container.argb == raw)
    }

    @Test("Exam cards use the exam palette")
    func examColor() {
        let exam = makeCourse(id: "a", category: .exam)
        let entry = CoursePalette.courseEntry(for: exam, style: .standard, dark: false)
        #expect(entry == CoursePalette.examEntry(dark: false))
    }

    @Test("Light fills get dark content and dark fills get light content")
    func readableContent() {
        #expect(CoursePalette.readableOn(RGBColor(hex: "#DDEBFA")!).hex == "#1F2A24")
        #expect(CoursePalette.readableOn(RGBColor(hex: "#243A52")!).hex == "#FFFFFF")
    }

    @Test("Accent presets are all distinct")
    func accentsDistinct() {
        let hexes = Set(AccentTheme.allCases.map(\.baseColor.hex))
        #expect(hexes.count == AccentTheme.allCases.count)
        #expect(AccentTheme.allCases.contains(.green))
    }
}
