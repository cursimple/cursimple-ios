import Foundation

public struct ClassSlotTime: Codable, Hashable, Sendable, Identifiable {

    public var startNode: Int
    public var endNode: Int
    /// `HH:mm`
    public var startTime: String
    /// `HH:mm`
    public var endTime: String
    /// Free-form label for imported or user-defined slots.
    public var label: String
    /// Built-in label identity; built-ins localize through this key.
    public var labelKey: String?

    public init(
        startNode: Int,
        endNode: Int,
        startTime: String,
        endTime: String,
        label: String = "",
        labelKey: String? = nil
    ) {
        self.startNode = startNode
        self.endNode = endNode
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
        self.labelKey = labelKey
    }

    public var id: String { "\(startNode)-\(endNode)" }

    public var start: TimeOfDay? { TimeOfDay(startTime) }
    public var end: TimeOfDay? { TimeOfDay(endTime) }

    public var isValid: Bool {
        guard let start, let end else { return false }
        return start < end && endNode >= startNode
    }
}

public struct TimingProfile: Codable, Identifiable, Hashable, Sendable {

    public static let defaultID = "default"
    public static let defaultNameKey = "default"

    public var id: String
    public var name: String
    public var nameKey: String?
    public var slots: [ClassSlotTime]
    public var timezone: String

    public init(
        id: String,
        name: String = "",
        nameKey: String? = nil,
        slots: [ClassSlotTime] = [],
        timezone: String = ""
    ) {
        self.id = id
        self.name = name
        self.nameKey = nameKey
        self.slots = slots
        self.timezone = timezone
    }

    public var maxNode: Int {
        max(slots.map(\.endNode).max() ?? 0, 1)
    }

    public func slot(startingAt node: Int) -> ClassSlotTime? {
        slots.first { $0.startNode == node }
    }

    public func slot(coveringNode node: Int) -> ClassSlotTime? {
        slots
            .filter { $0.endNode >= $0.startNode }
            .sorted { ($0.startNode, $0.endNode) < ($1.startNode, $1.endNode) }
            .first { $0.startNode <= node && $0.endNode >= node }
    }

    public func slot(startNode: Int, endNode: Int) -> ClassSlotTime? {
        slots.first { $0.startNode == startNode && $0.endNode == endNode }
    }

    /// Replace a slot with the same node range, or append it.
    public func upserting(_ slot: ClassSlotTime) -> TimingProfile {
        var next = self
        if let index = next.slots.firstIndex(where: { $0.startNode == slot.startNode && $0.endNode == slot.endNode }) {
            next.slots[index] = slot
        } else {
            next.slots.append(slot)
        }
        next.slots.sort { ($0.startNode, $0.endNode) < ($1.startNode, $1.endNode) }
        return next
    }

    public func removing(node: Int) -> TimingProfile {
        var next = self
        next.slots.removeAll { $0.startNode == node && $0.endNode == node }
        return next
    }

    public static func defaultProfile() -> TimingProfile {
        let times: [(String, String)] = [
            ("08:00", "08:45"),
            ("08:55", "09:40"),
            ("10:00", "10:45"),
            ("10:55", "11:40"),
            ("14:00", "14:45"),
            ("14:55", "15:40"),
            ("16:00", "16:45"),
            ("16:55", "17:40"),
            ("19:00", "19:45"),
            ("19:55", "20:40"),
            ("20:50", "21:35"),
        ]
        let slots = times.enumerated().map { index, pair in
            ClassSlotTime(
                startNode: index + 1,
                endNode: index + 1,
                startTime: pair.0,
                endTime: pair.1,
                labelKey: "period"
            )
        }
        return TimingProfile(
            id: defaultID,
            nameKey: defaultNameKey,
            slots: slots,
            timezone: TimeZone.current.identifier
        )
    }
}
