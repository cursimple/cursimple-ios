import Foundation

/// One school in the fixed catalog: either a portal URL opened directly, or a
/// plugin repository binding.
public struct SchoolPortalEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var portalUrl: String?
    public var pluginRepo: String?
    public var pluginId: String?
    public var tiers: [String]
    /// `yyyy-MM-dd` and period times, when the catalog ships them.
    public var timingProfile: SchoolTimingProfile?

    public init(
        id: String,
        name: String,
        portalUrl: String? = nil,
        pluginRepo: String? = nil,
        pluginId: String? = nil,
        tiers: [String] = [],
        timingProfile: SchoolTimingProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.portalUrl = portalUrl
        self.pluginRepo = pluginRepo
        self.pluginId = pluginId
        self.tiers = tiers
        self.timingProfile = timingProfile
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, portalUrl, pluginRepo, pluginId, tiers, timingProfile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        portalUrl = try container.decodeIfPresent(String.self, forKey: .portalUrl)
        pluginRepo = try container.decodeIfPresent(String.self, forKey: .pluginRepo)
        pluginId = try container.decodeIfPresent(String.self, forKey: .pluginId)
        tiers = try container.decodeIfPresent([String].self, forKey: .tiers) ?? []
        timingProfile = try? container.decodeIfPresent(SchoolTimingProfile.self, forKey: .timingProfile)
    }

    public var usesPlugin: Bool {
        !(pluginRepo ?? "").isEmpty
    }

    public var host: String? {
        guard let portalUrl, let url = URL(string: portalUrl) else { return nil }
        return url.host
    }
}

public struct SchoolTimingProfile: Codable, Hashable, Sendable {
    public var termStartDate: String?
    public var slotTimes: [ClassSlotTime]
    public var timezone: String?

    public init(termStartDate: String? = nil, slotTimes: [ClassSlotTime] = [], timezone: String? = nil) {
        self.termStartDate = termStartDate
        self.slotTimes = slotTimes
        self.timezone = timezone
    }

    private enum CodingKeys: String, CodingKey {
        case termStartDate, slotTimes, timezone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        termStartDate = try container.decodeIfPresent(String.self, forKey: .termStartDate)
        slotTimes = try container.decodeIfPresent([ClassSlotTime].self, forKey: .slotTimes) ?? []
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
    }
}

/// The bundled school list and the hosts a portal session may visit.
public enum SchoolPortalCatalog {

    public static let pluginID = "builtin.school-portal"

    /// Public suffixes that must never be widened to a parent domain.
    private static let publicSuffixes: Set<String> = [
        "edu.cn", "ac.cn", "com.cn", "net.cn", "org.cn", "gov.cn",
        "com", "net", "org", "cn", "edu", "io",
    ]

    public static func loadBundled() -> [SchoolPortalEntry] {
        guard let url = Bundle.module.url(forResource: "schools", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SchoolPortalEntry].self, from: data) else {
            return []
        }
        return entries
    }

    /// Case-insensitive substring match on the school name; blank returns everything.
    public static func search(_ entries: [SchoolPortalEntry], query: String) -> [SchoolPortalEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return entries }
        return entries.filter { $0.name.lowercased().contains(needle) }
    }

    /// Hosts a portal session may visit: the portal host plus its school domain,
    /// so single sign-on pages on sibling subdomains work. Public suffixes are
    /// never widened.
    public static func allowedHosts(for entry: SchoolPortalEntry) -> [String] {
        guard let host = entry.host?.lowercased(), !host.isEmpty else { return [] }
        var hosts: [String] = [host]
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 3 else { return hosts }

        let registrable = parts.suffix(2).joined(separator: ".")
        if publicSuffixes.contains(registrable) {
            // Drop the leftmost label only (jwxt.example.edu.cn -> example.edu.cn).
            let parent = parts.dropFirst().joined(separator: ".")
            if !publicSuffixes.contains(parent) { hosts.append(parent) }
        } else {
            hosts.append(registrable)
        }
        return hosts
    }

    /// Whether a navigation target stays inside the entry's allowed hosts.
    public static func isAllowed(_ url: URL, for entry: SchoolPortalEntry) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowedHosts(for: entry).contains { allowed in
            host == allowed || host.hasSuffix("." + allowed)
        }
    }
}
