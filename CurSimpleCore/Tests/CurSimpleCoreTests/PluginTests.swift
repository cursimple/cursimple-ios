import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Plugin manifest")
struct PluginManifestTests {

    private func manifest(
        id: String = "edu.example.schedule",
        apiVersion: Int? = 2,
        minHostVersion: String = "0.1.0",
        entry: String = "main.js",
        kind: PluginKind = .schedule,
        allowedHosts: [String] = ["portal.example.edu"],
        startUrl: String? = nil
    ) -> PluginManifest {
        PluginManifest(
            id: id,
            name: "Example",
            version: "1.0.0",
            versionCode: 1,
            apiVersion: apiVersion,
            entry: entry,
            allowedHosts: allowedHosts,
            startUrl: startUrl,
            minHostVersion: minHostVersion,
            kind: kind
        )
    }

    @Test("Valid manifests pass and normalize the entry path")
    func valid() throws {
        let validated = try validatePluginManifest(
            manifest(entry: "./main.js"),
            availableFiles: ["main.js", "checksums.json"],
            hostVersion: "0.8.2"
        )
        #expect(validated.entry == "main.js")
    }

    @Test("Unsafe ids and paths are rejected")
    func unsafe() {
        #expect(!isValidPluginID("nodot"))
        #expect(!isValidPluginID("Bad.ID"))
        #expect(isValidPluginID("edu.example.schedule"))
        #expect(throws: PluginInstallError.unsafePath("/etc/passwd")) {
            try normalizePluginPath("/etc/passwd")
        }
        #expect(throws: PluginInstallError.unsafePath("../secret")) {
            try normalizePluginPath("../secret")
        }
        #expect(throws: PluginInstallError.unsafePath("a\\b")) {
            try normalizePluginPath("a\\b")
        }
    }

    @Test("Newer API, old host and missing entry are rejected")
    func compatibility() {
        #expect(throws: PluginInstallError.unsupportedApi(99)) {
            try validatePluginManifest(
                manifest(apiVersion: 99),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
        #expect(throws: PluginInstallError.hostTooOld(required: "0.9.0")) {
            try validatePluginManifest(
                manifest(minHostVersion: "0.9.0"),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
        #expect(throws: PluginInstallError.missingEntry("missing.js")) {
            try validatePluginManifest(
                manifest(entry: "missing.js"),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
    }

    @Test("Extensions require API 3")
    func extensionApi() {
        #expect(throws: PluginInstallError.extensionRequiresApi3) {
            try validatePluginManifest(
                manifest(apiVersion: 2, kind: .extension),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
        #expect(throws: Never.self) {
            try validatePluginManifest(
                manifest(apiVersion: 3, kind: .extension),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
    }

    @Test("Start URL must stay inside allowed hosts")
    func startUrl() {
        #expect(throws: Never.self) {
            try validatePluginManifest(
                manifest(startUrl: "https://portal.example.edu/login"),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
        #expect(throws: PluginInstallError.hostOutsideAllowedHosts("evil.example.com")) {
            try validatePluginManifest(
                manifest(startUrl: "https://evil.example.com/login"),
                availableFiles: ["main.js"],
                hostVersion: "0.8.2"
            )
        }
    }

    @Test("Version comparison handles numbers and prereleases")
    func versions() {
        #expect(comparePluginVersions("0.8.2", "0.8.2") == .orderedSame)
        #expect(comparePluginVersions("0.8.10", "0.8.9") == .orderedDescending)
        #expect(comparePluginVersions("0.9.0", "0.8.9") == .orderedDescending)
        #expect(comparePluginVersions("0.9.0-pre.1", "0.9.0") == .orderedAscending)
    }

    @Test("Checksums must cover every non-metadata file")
    func checksums() throws {
        let files: [String: Data] = [
            "main.js": Data("console.log(1)".utf8),
            "checksums.json": Data("{}".utf8),
        ]
        let declared = pluginChecksums(files)

        #expect(throws: Never.self) {
            try verifyPluginChecksums(files: files, declared: declared)
        }

        var tampered = files
        tampered["main.js"] = Data("console.log(2)".utf8)
        #expect(throws: PluginInstallError.checksumMismatch("main.js")) {
            try verifyPluginChecksums(files: tampered, declared: declared)
        }

        #expect(throws: PluginInstallError.checksumMismatch("main.js")) {
            try verifyPluginChecksums(files: files, declared: [:])
        }
    }
}

@Suite("Schedule draft")
struct ScheduleDraftTests {

    @Test("Drafts normalize into courses with stable ids")
    func validDraft() throws {
        let draft = ScheduleDraft(termId: "2026-2027-1", courses: [
            ScheduleDraftCourse(
                title: "  高等数学  ",
                teacher: " 张老师 ",
                location: " A101 ",
                dayOfWeek: 1,
                startNode: 1,
                endNode: 2,
                weeks: [3, 1, 1, 2],
                details: [
                    CourseDetailField(label: " 学分 ", value: " 4 "),
                    CourseDetailField(label: "学分", value: "重复"),
                    CourseDetailField(label: "", value: "空标签"),
                ]
            ),
        ])

        let courses = try coursesFromDraft(draft)
        #expect(courses.count == 1)
        #expect(courses[0].title == "高等数学")
        #expect(courses[0].teacher == "张老师")
        #expect(courses[0].weeks == [1, 2, 3])
        #expect(courses[0].details == [CourseDetailField(label: "学分", value: "4")])
        #expect(courses[0].id.hasPrefix("plugin-"))
    }

    @Test("Out-of-range values are rejected")
    func invalid() {
        #expect(throws: ScheduleDraftError.blankTitle(0)) {
            try coursesFromDraft(ScheduleDraft(termId: "t", courses: [
                ScheduleDraftCourse(title: "  ", dayOfWeek: 1, startNode: 1, endNode: 2),
            ]))
        }
        #expect(throws: ScheduleDraftError.invalidDayOfWeek(8)) {
            try coursesFromDraft(ScheduleDraft(termId: "t", courses: [
                ScheduleDraftCourse(title: "x", dayOfWeek: 8, startNode: 1, endNode: 2),
            ]))
        }
        #expect(throws: ScheduleDraftError.invalidEndNode(0)) {
            try coursesFromDraft(ScheduleDraft(termId: "t", courses: [
                ScheduleDraftCourse(title: "x", dayOfWeek: 1, startNode: 3, endNode: 0),
            ]))
        }
        #expect(throws: ScheduleDraftError.invalidWeeks(0)) {
            try coursesFromDraft(ScheduleDraft(termId: "t", courses: [
                ScheduleDraftCourse(title: "x", dayOfWeek: 1, startNode: 1, endNode: 2, weeks: [0]),
            ]))
        }
    }

    @Test("Course count limit applies")
    func limits() {
        let many = (0..<5).map { index in
            ScheduleDraftCourse(title: "c\(index)", dayOfWeek: 1, startNode: 1, endNode: 2)
        }
        #expect(throws: ScheduleDraftError.tooManyCourses) {
            try coursesFromDraft(
                ScheduleDraft(termId: "t", courses: many),
                limits: PluginRuntimeLimits(maxCourses: 4)
            )
        }
    }

    @Test("Drafts decode from the JSON the bridge sends")
    func decoding() throws {
        let json = """
        {"termId":"2026-1","courses":[
          {"title":"大学英语","dayOfWeek":2,"startNode":3,"endNode":4,"weeks":[1,2],
           "category":"exam","details":[{"label":"教室","value":"B305"}]}
        ]}
        """
        let draft = try decodeScheduleDraft(json)
        let courses = try coursesFromDraft(draft)
        #expect(courses.count == 1)
        #expect(courses[0].category == .exam)
        #expect(courses[0].details.first?.value == "B305")
        #expect(draft.termId == "2026-1")
    }

    @Test("Draft courses sort by day, period and title")
    func sorting() throws {
        let draft = ScheduleDraft(termId: "t", courses: [
            ScheduleDraftCourse(title: "b", dayOfWeek: 2, startNode: 1, endNode: 2),
            ScheduleDraftCourse(title: "a", dayOfWeek: 1, startNode: 5, endNode: 6),
            ScheduleDraftCourse(title: "a", dayOfWeek: 1, startNode: 1, endNode: 2),
        ])
        let courses = try coursesFromDraft(draft)
        #expect(courses.map(\.title) == ["a", "a", "b"])
        #expect(courses.map { $0.time.dayOfWeek } == [1, 1, 2])
    }
}
