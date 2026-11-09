import Foundation
import Testing
@testable import CurSimpleCore

@Suite("School portal catalog")
struct SchoolCatalogTests {

    private func entry(
        name: String = "测试大学",
        portalUrl: String? = "https://jwxt.example.edu.cn/cas/login.action"
    ) -> SchoolPortalEntry {
        SchoolPortalEntry(id: "s1", name: name, portalUrl: portalUrl)
    }

    @Test("The bundled catalog decodes with portals and names")
    func bundled() {
        let entries = SchoolPortalCatalog.loadBundled()
        #expect(entries.count > 700)
        #expect(entries.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty })
        #expect(entries.contains { $0.portalUrl != nil })
        #expect(Set(entries.map(\.id)).count == entries.count)
    }

    @Test("Search matches names case-insensitively and blank returns all")
    func search() {
        let entries = [
            SchoolPortalEntry(id: "a", name: "上海交通大学"),
            SchoolPortalEntry(id: "b", name: "Shanghai Tech"),
            SchoolPortalEntry(id: "c", name: "北京大学"),
        ]
        #expect(SchoolPortalCatalog.search(entries, query: "上海").map(\.id) == ["a"])
        #expect(SchoolPortalCatalog.search(entries, query: "shanghai").map(\.id) == ["b"])
        #expect(SchoolPortalCatalog.search(entries, query: "   ").count == 3)
        #expect(SchoolPortalCatalog.search(entries, query: "不存在").isEmpty)
    }

    @Test("Allowed hosts include the portal and its school domain")
    func allowedHosts() {
        let hosts = SchoolPortalCatalog.allowedHosts(for: entry())
        #expect(hosts.contains("jwxt.example.edu.cn"))
        #expect(hosts.contains("example.edu.cn"))
        // A public suffix must never be widened to.
        #expect(!hosts.contains("edu.cn"))
        #expect(!hosts.contains("cn"))
    }

    @Test("Two-label hosts stay exact")
    func shortHost() {
        let hosts = SchoolPortalCatalog.allowedHosts(
            for: entry(portalUrl: "https://example.com/login")
        )
        #expect(hosts == ["example.com"])
    }

    @Test("Navigation outside the school domain is blocked")
    func navigationPolicy() throws {
        let target = entry()
        #expect(SchoolPortalCatalog.isAllowed(URL(string: "https://jwxt.example.edu.cn/a")!, for: target))
        #expect(SchoolPortalCatalog.isAllowed(URL(string: "https://cas.example.edu.cn/a")!, for: target))
        #expect(!SchoolPortalCatalog.isAllowed(URL(string: "https://evil.com/a")!, for: target))
        #expect(!SchoolPortalCatalog.isAllowed(URL(string: "https://example.edu.cn.evil.com/a")!, for: target))
    }

    @Test("Entries without a portal URL expose no hosts")
    func missingPortal() {
        #expect(SchoolPortalCatalog.allowedHosts(for: entry(portalUrl: nil)).isEmpty)
    }
}
