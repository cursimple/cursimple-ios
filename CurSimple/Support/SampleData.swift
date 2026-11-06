#if DEBUG
import CurSimpleCore

enum SampleData {

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
