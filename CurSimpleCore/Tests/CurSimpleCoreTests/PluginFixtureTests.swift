import Foundation
import Testing
@testable import CurSimpleCore

/// End-to-end check against a real DEFLATE-compressed plugin archive produced by
/// Python's zipfile, matching how plugin bundles are distributed.
@Suite("Plugin bundle fixture")
struct PluginFixtureTests {

    private let base64 = """
UEsDBBQAAAAIAGNNaV37bumb2gAAABYBAAANAAAAbWFuaWZlc3QuanNvbqtWykxRslJQSk0p1UutSMwtyEnVK07OAHJzUpV0FJTy
EnNTQfLPl+x6sq/76dplzxYsBImXpRYVZ+bngaQM9Qz0DJDEnPNTQFoMgSKJBZlhcIVGQIHUvJKiSpCm3MTMPL2sYpC2xJyc/PLU
FI/84pJioFS0UkF+UUliDtw5QLcoxQLVFaQW5WYWgwyDKCtPTdIrSk1MiU/JzwWZA3O2XnlRZkkqWEtKanFyUWZBCdSlz6eseLKr
7+WqnhfrG5+u3/O0demzrY3PV3Q/n9UC8d+z/klPdm9TqgUAUEsDBBQAAAAIAGNNaV2rVphlFgAAABQAAAAHAAAAbWFpbi5qc0vO
zyvOz0nVy8lP11BPSc3NV9e0BgBQSwECFAMUAAAACABjTWld+27pm9oAAAAWAQAADQAAAAAAAAAAAAAAgAEAAAAAbWFuaWZlc3Qu
anNvblBLAQIUAxQAAAAIAGNNaV2rVphlFgAAABQAAAAHAAAAAAAAAAAAAACAAQUBAABtYWluLmpzUEsFBgAAAAACAAIAcAAAAEAB
AAAAAA==
"""

    private var archive: Data {
        Data(base64Encoded: base64.filter { !$0.isWhitespace })!
    }

    @Test("The real archive unzips, validates and yields a runnable script")
    func installPath() throws {
        let entries = try ZipArchive.read(archive)
        let files = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0.data) })
        #expect(files.keys.contains("manifest.json"))
        #expect(files.keys.contains("main.js"))

        let manifest = try JSONDecoder().decode(PluginManifest.self, from: files["manifest.json"]!)
        let validated = try validatePluginManifest(
            manifest,
            availableFiles: Set(files.keys),
            hostVersion: "0.8.2"
        )
        #expect(validated.id == "edu.example.schedule")
        #expect(validated.has(.scheduleWrite))
        #expect(validated.allowedHosts == ["portal.example.edu"])

        let script = String(data: files[validated.entry]!, encoding: .utf8)
        #expect(script?.contains("console.log") == true)
    }

    @Test("A draft from this plugin imports into a term")
    func draftImport() throws {
        let json = """
        {"termId":"2026-2027-1","courses":[
          {"title":"线性代数","teacher":"李老师","location":"A101",
            "dayOfWeek":3,"startNode":1,"endNode":2,"weeks":[1,2,3,4,5,6,7,8]}
        ]}
        """
        let courses = try coursesFromDraft(decodeScheduleDraft(json))
        #expect(courses.count == 1)
        #expect(courses[0].id.hasPrefix("plugin-"))
        #expect(courses[0].weeks.count == 8)
    }
}
