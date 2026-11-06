#if DEBUG
import CurSimpleCore
import Foundation

enum SampleData {

    static func memos() -> [MemoNote] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return [
            MemoNote(
                id: "memo-1", courseKey: "计算机网络", courseTitle: "计算机网络",
                title: "复习第三章", body: "套接字、TCP 三次握手\n- [x] 看完课件\n- [ ] 做课后题 1-5",
                priority: .high, pinned: true, dueAt: dueString(days: -1, hour: 18),
                createdAt: now - 100_000, updatedAt: now - 90_000
            ),
            MemoNote(
                id: "memo-2", courseKey: "高等数学", courseTitle: "高等数学",
                title: "交作业", body: "第五章习题抄在本子上",
                priority: .medium, dueAt: dueString(days: 0, hour: 22),
                createdAt: now - 80_000, updatedAt: now - 70_000
            ),
            MemoNote(
                id: "memo-3", courseKey: nil, courseTitle: "",
                title: "社团招新海报", body: "周四前发给宣传部\n- [ ] 定稿\n- [ ] 打印 20 份",
                priority: .low, dueAt: dueString(days: 2, hour: 12),
                createdAt: now - 60_000, updatedAt: now - 50_000
            ),
            MemoNote(
                id: "memo-4", courseKey: nil, courseTitle: "",
                title: "买电动车充电器",
                body: "原来的充不上电了",
                createdAt: now - 40_000, updatedAt: now - 30_000
            ),
            MemoNote(
                id: "memo-5", courseKey: "大学英语", courseTitle: "大学英语",
                title: "口语作业", body: "已提交",
                completed: true, createdAt: now - 200_000, updatedAt: now - 20_000
            ),
        ]
    }

    private static func dueString(days: Int, hour: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Calendar.current.date(from: components) ?? date)
    }

    static func holidayCalendar() -> HolidayCalendarSettings {
        let friday = Calendar.current.date(byAdding: .day, value: 11, to: mondayOfCurrentWeek()) ?? .now
        var settings = HolidayCalendarSettings()
        settings = settings.upsertingUser(HolidayCalendarEntry(
            date: DateOnly.string(from: friday),
            kind: .holiday,
            name: "校庆"
        ))
        return settings
    }

    static func overrides(courses: [CourseItem]) -> [TemporaryScheduleOverride] {
        guard let course = courses.first else { return [] }
        let nextMonday = Calendar.current.date(byAdding: .day, value: 7, to: mondayOfCurrentWeek()) ?? .now
        let nextWednesday = Calendar.current.date(byAdding: .day, value: 9, to: mondayOfCurrentWeek()) ?? .now
        return [
            TemporaryScheduleOverride(
                type: .cancelCourse,
                targetDate: DateOnly.string(from: nextMonday),
                cancelStartNode: course.time.startNode,
                cancelEndNode: course.time.endNode,
                cancelCourseId: course.id
            ),
            TemporaryScheduleOverride(
                type: .moveCourse,
                targetDate: DateOnly.string(from: nextWednesday),
                sourceDate: DateOnly.string(from: nextMonday),
                moveCourseId: courses.count > 1 ? courses[1].id : course.id,
                moveToStartNode: 7,
                moveToEndNode: 8
            ),
        ]
    }

    private static func mondayOfCurrentWeek() -> Date {
        ScheduleCalendar.startOfDisplayWeek(containing: .now, weekStart: .monday)
    }

    static func courses() -> [CourseItem] {
        [
            course("高数", "高等数学", day: 1, start: 1, end: 2, location: "教学楼-A201", teacher: "张老师"),
            course("数据结构", "数据结构", day: 1, start: 3, end: 4, location: "信息楼-C204", teacher: "李老师"),
            course("线代", "线性代数", day: 1, start: 5, end: 6, location: "明德楼-A105"),
            course("英语", "大学英语", day: 2, start: 1, end: 2, location: "博文楼-B305"),
            course("大物", "大学物理", day: 2, start: 3, end: 4, location: "格物楼-D210", teacher: "王老师"),
            course("思政", "思想道德与法治", day: 2, start: 5, end: 6, location: "博文楼-B101", teacher: "赵老师"),
            course("计网", "计算机网络", day: 3, start: 3, end: 4, location: "信息楼-C301"),
            course("程设", "程序设计基础", day: 3, start: 5, end: 6, location: "信息楼-机房-2"),
            course("体育", "体育（羽毛球）", day: 4, start: 7, end: 8, location: "体育馆-2楼"),
            course("大物实验", "大学物理实验", day: 4, start: 7, end: 8, location: "格物楼实验室-3"),
            course("计网2", "计算机网络", day: 5, start: 5, end: 6, location: "信息楼-C301"),
            course("羽毛球", "羽毛球", day: 5, start: 7, end: 8, location: "体育馆"),
            exam("高数考试", "高等数学考试", day: 5, start: 9, end: 10, location: "教学楼-A201"),
        ]
    }

    private static func course(
        _ id: String,
        _ title: String,
        day: Int,
        start: Int,
        end: Int,
        location: String,
        teacher: String = ""
    ) -> CourseItem {
        CourseItem(
            id: id,
            title: title,
            teacher: teacher,
            location: location,
            time: CourseTimeSlot(dayOfWeek: day, startNode: start, endNode: end)
        )
    }

    private static func exam(
        _ id: String,
        _ title: String,
        day: Int,
        start: Int,
        end: Int,
        location: String
    ) -> CourseItem {
        var item = course(id, title, day: day, start: start, end: end, location: location)
        item.category = .exam
        return item
    }
}
#endif
