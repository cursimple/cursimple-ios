import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Memo checklist")
struct MemoChecklistTests {

    @Test("Checkbox lines parse with indentation and bullets")
    func parseVariants() {
        let plain = MemoChecklist.parseLine("- [ ] 买书")
        #expect(plain?.checked == false)
        #expect(plain?.text == "买书")

        let checked = MemoChecklist.parseLine("- [x] 买书")
        #expect(checked?.checked == true)

        let upper = MemoChecklist.parseLine("- [X] 买书")
        #expect(upper?.checked == true)

        let star = MemoChecklist.parseLine("* [ ] 买书")
        #expect(star?.checked == false)

        let indented = MemoChecklist.parseLine("  - [ ] 缩进")
        #expect(indented?.checked == false)

        #expect(MemoChecklist.parseLine("- 买书") == nil)
        #expect(MemoChecklist.parseLine("普通段落") == nil)
    }

    @Test("Progress counts done and total")
    func progress() {
        let body = "第一段\n- [x] 已办\n- [ ] 未办\n中间文字\n* [X] 也算\n"
        let progress = MemoChecklist.progress(of: body)
        #expect(progress.done == 2)
        #expect(progress.total == 3)
        #expect(abs(progress.fraction - 2.0 / 3.0) < 0.001)
    }

    @Test("Empty body has no items")
    func empty() {
        #expect(!MemoChecklist.progress(of: "").hasItems)
        #expect(!MemoChecklist.progress(of: "只有文字").hasItems)
    }

    @Test("Toggle flips the marker at the given line only")
    func toggleLine() {
        let body = "- [ ] 甲\n文字\n- [ ] 乙"
        let toggled = MemoChecklist.togglingLine(body, lineIndex: 0)
        #expect(toggled == "- [x] 甲\n文字\n- [ ] 乙")

        let untoggled = MemoChecklist.togglingLine(toggled, lineIndex: 0)
        #expect(untoggled == body)

        // Non-checkbox line is untouched.
        #expect(MemoChecklist.togglingLine(body, lineIndex: 1) == body)
    }

    @Test("Toggle by item text finds the matching checkbox")
    func toggleByText() {
        let body = "- [ ] 甲\n- [ ] 乙"
        let toggled = MemoChecklist.togglingItem(body, text: "乙")
        #expect(toggled == "- [ ] 甲\n- [x] 乙")
    }

    @Test("Append inserts after the last checkbox")
    func append() {
        #expect(MemoChecklist.appendingItem("", text: "新项") == "- [ ] 新项")
        #expect(MemoChecklist.appendingItem("前言", text: "新项") == "前言\n- [ ] 新项")

        let body = "- [x] 甲\n尾段"
        #expect(MemoChecklist.appendingItem(body, text: "新项") == "- [x] 甲\n- [ ] 新项\n尾段")
    }
}

@Suite("Memo sorting and due states")
struct MemoOrderTests {

    let calendar = makeTestCalendar()

    private func date(_ value: String, hour: Int = 12) -> Date {
        var components = DateComponents()
        let parts = value.split(separator: "-").compactMap { Int($0) }
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = hour
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    private func note(
        id: String,
        pinned: Bool = false,
        completed: Bool = false,
        priority: MemoPriority = .none,
        dueAt: String? = nil,
        updatedAt: Int64 = 0
    ) -> MemoNote {
        MemoNote(
            id: id,
            title: id,
            priority: priority,
            pinned: pinned,
            dueAt: dueAt,
            completed: completed,
            updatedAt: updatedAt
        )
    }

    @Test("Due states bucket by deadline")
    func dueStates() {
        let now = date("2026-11-06", hour: 10)

        #expect(note(id: "a", dueAt: "2026-11-05T08:00").dueState(at: now, calendar: calendar) == .overdue)
        #expect(note(id: "b", dueAt: "2026-11-06T23:00").dueState(at: now, calendar: calendar) == .today)
        #expect(note(id: "c", dueAt: "2026-11-08T08:00").dueState(at: now, calendar: calendar) == .soon)
        #expect(note(id: "d", dueAt: "2026-11-20T08:00").dueState(at: now, calendar: calendar) == .later)
        #expect(note(id: "e").dueState(at: now, calendar: calendar) == .none)
        #expect(note(id: "f", completed: true, dueAt: "2026-11-01T08:00").dueState(at: now, calendar: calendar) == .later)
    }

    @Test("Completed sink, pinned float, deadlines order the rest")
    func comparator() {
        let now = date("2026-11-06", hour: 10)
        let sort = memoComparator(now: now, calendar: calendar)

        let pinned = note(id: "pinned", pinned: true)
        let overdue = note(id: "overdue", dueAt: "2026-11-01T08:00")
        let today = note(id: "today", dueAt: "2026-11-06T18:00")
        let plain = note(id: "plain")
        let done = note(id: "done", completed: true)

        let notes = [done, plain, today, overdue, pinned].sorted(by: sort)
        #expect(notes.map(\.id) == ["pinned", "overdue", "today", "plain", "done"])
    }

    @Test("Same bucket: closer deadline first, then priority, then recent edit")
    func tieBreakers() {
        let now = date("2026-11-06", hour: 10)
        let sort = memoComparator(now: now, calendar: calendar)

        let later = note(id: "later", dueAt: "2026-11-07T08:00")
        let sooner = note(id: "sooner", dueAt: "2026-11-07T06:00")
        #expect(sort(sooner, later))

        let high = note(id: "high", priority: .high, updatedAt: 1)
        let low = note(id: "low", priority: .low, updatedAt: 99)
        #expect(sort(high, low))

        let recent = note(id: "recent", updatedAt: 200)
        let older = note(id: "older", updatedAt: 100)
        #expect(sort(recent, older))
    }
}

@Suite("Memo note basics")
struct MemoNoteTests {

    @Test("Display title falls back to the first body line")
    func displayTitle() {
        #expect(MemoNote(title: "标题").displayTitle == "标题")
        #expect(MemoNote(body: "首行正文\n第二行").displayTitle == "首行正文")
        #expect(MemoNote().displayTitle.isEmpty)
    }

    @Test("Backward-compatible decoding with missing fields")
    func decoding() throws {
        let json = """
        { "id": "n1", "title": "只有标题" }
        """.data(using: .utf8)!
        let note = try JSONDecoder().decode(MemoNote.self, from: json)
        #expect(note.priority == .none)
        #expect(note.pinned == false)
        #expect(note.completed == false)
        #expect(note.courseKey == nil)
    }
}
