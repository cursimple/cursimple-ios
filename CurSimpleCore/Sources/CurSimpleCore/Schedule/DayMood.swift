import Foundation

/// Date-seeded idle-state messages stay consistent throughout the day.
public enum DayMood: Int, CaseIterable, Sendable {
    case lateNight
    case weekendFree
    case sundayNight
    case weekdayFree
    case doneTomorrowHoliday
    case doneFriday
    case doneEvening
    case done
}

public struct DayMoodContext: Sendable {
    public let date: Date
    public let hour: Int
    public let isoWeekday: Int
    public let totalCourses: Int
    /// Known "tomorrow is a holiday" hint; nil when unknown. iOS has no holiday
    /// calendar yet, so this stays nil in the app and the holiday cases never fire.
    public let tomorrowIsHoliday: Bool?

    public init(
        date: Date,
        hour: Int,
        isoWeekday: Int,
        totalCourses: Int,
        tomorrowIsHoliday: Bool? = nil
    ) {
        self.date = date
        self.hour = hour
        self.isoWeekday = isoWeekday
        self.totalCourses = totalCourses
        self.tomorrowIsHoliday = tomorrowIsHoliday
    }
}

private let lateNightStart = 23
private let lateNightEnd = 5
private let eveningStart = 18

public func dayMood(for context: DayMoodContext) -> DayMood? {
    if context.hour >= lateNightStart || context.hour < lateNightEnd {
        return .lateNight
    }
    if context.totalCourses == 0 {
        switch context.isoWeekday {
        case 7: return context.hour >= eveningStart ? .sundayNight : .weekendFree
        case 6: return .weekendFree
        default: return .weekdayFree
        }
    }
    if context.tomorrowIsHoliday == true { return .doneTomorrowHoliday }
    if context.isoWeekday == 5 { return .doneFriday }
    if context.hour >= eveningStart { return .doneEvening }
    return .done
}

/// Same day-seeded selection as the existing platform: stable for the whole day.
public func dayMoodLineIndex(date: Date, mood: DayMood, size: Int, calendar: Calendar = .current) -> Int {
    guard size > 1 else { return 0 }
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    var seed = UInt64(day) * 31 &+ UInt64(mood.rawValue)
    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Int((seed >> 33) % UInt64(size))
}

public func moodLines(for mood: DayMood, locale: String) -> [String] {
    let table: [[String]]
    if locale.hasPrefix("zh-Hant") || locale.hasPrefix("zh-TW") {
        table = traditionalMoodTable
    } else if locale.hasPrefix("zh") {
        table = simplifiedMoodTable
    } else {
        table = englishMoodTable
    }
    return table[mood.rawValue]
}

private let simplifiedMoodTable: [[String]] = [
    // lateNight
    ["夜深了，课表也要睡了", "这个点还醒着？早点睡，明天的你会谢谢你", "熬夜不加学分，早点睡吧", "星星都下班了，你也歇歇吧", "夜猫子，记得给明天留点电", "放下手机，做个好梦"],
    // weekendFree
    ["周末没课，睡到自然醒", "今天课表放空，去晒晒太阳", "周末愉快，做点和学习无关的事", "难得清闲，奖励自己一杯奶茶", "没课的周末，最适合发呆", "休息也是功课的一部分"],
    // sundayNight
    ["周末余额不足，明天见", "周日晚上，记得收拾书包", "新的一周快开始了，早点休息", "明天有课，今晚别熬太晚"],
    // weekdayFree
    ["今天没课，偷得浮生半日闲", "工作日没课，是课表送你的礼物", "难得空闲，去图书馆或者去睡觉", "没课的一天，节奏自己定", "今天的时间全归你"],
    // doneTomorrowHoliday
    ["课上完了，明天放假！", "今天收工，假期就在明天", "下课铃一响，假期开始倒计时", "最后一节已结束，准备放假吧"],
    // doneFriday
    ["本周课程全部通关，周末快乐", "周五下课，周末启动", "一周辛苦了，好好犒劳自己", "课都上完了，周末去哪儿玩？"],
    // doneEvening
    ["今天的课都上完了，晚上好好放松", "辛苦一天，吃顿好的", "下课啦，今晚的时间都是你的", "课程已结束，记得早点休息"],
    // done
    ["今天的课都上完了，辛苦啦", "今日课程已通关", "下课啦，剩下的时间归你", "收工！今天表现不错", "今天的任务完成，去做喜欢的事吧"],
]

private let traditionalMoodTable: [[String]] = [
    ["夜深了，課表也要睡了", "這個點還醒著？早點睡，明天的你會謝謝你", "熬夜不加學分，早點睡吧", "星星都下班了，你也歇歇吧", "夜貓子，記得給明天留點電", "放下手機，做個好夢"],
    ["週末沒課，睡到自然醒", "今天課表放空，去曬曬太陽", "週末愉快，做點和學習無關的事", "難得清閒，獎勵自己一杯奶茶", "沒課的週末，最適合發呆", "休息也是功課的一部分"],
    ["週末餘額不足，明天見", "週日晚上，記得收拾書包", "新的一週快開始了，早點休息", "明天有課，今晚別熬太晚"],
    ["今天沒課，偷得浮生半日閒", "工作日沒課，是課表送你的禮物", "難得空閒，去圖書館或者去睡覺", "沒課的一天，節奏自己定", "今天的時間全歸你"],
    ["課上完了，明天放假！", "今天收工，假期就在明天", "下課鈴一響，假期開始倒數", "最後一節已結束，準備放假吧"],
    ["本週課程全部通關，週末快樂", "週五下課，週末啟動", "一週辛苦了，好好犒勞自己", "課都上完了，週末去哪兒玩？"],
    ["今天的課都上完了，晚上好好放鬆", "辛苦一天，吃頓好的", "下課啦，今晚的時間都是你的", "課程已結束，記得早點休息"],
    ["今天的課都上完了，辛苦啦", "今日課程已通關", "下課啦，剩下的時間歸你", "收工！今天表現不錯", "今天的任務完成，去做喜歡的事吧"],
]

private let englishMoodTable: [[String]] = [
    ["It's late — even the timetable is asleep", "Still up? Sleep now, thank yourself tomorrow", "All-nighters earn no credits. Go rest", "The stars are off duty. You should be too", "Night owl, save some battery for tomorrow", "Put the phone down and dream well"],
    ["No classes this weekend. Sleep in", "Empty timetable. Go get some sun", "Happy weekend. Do something that isn't studying", "Rest is part of the curriculum too", "A quiet weekend suits daydreaming"],
    ["Weekend balance low. See you tomorrow", "Sunday night: pack your bag", "New week tomorrow. Get some rest", "Classes tomorrow — don't stay up too late"],
    ["No classes today. Enjoy the slack", "A free weekday, courtesy of your timetable", "Library or nap? Your call", "Today is all yours"],
    ["Classes done. Day off tomorrow!", "That's a wrap. The holiday starts tomorrow", "The bell rang — holiday countdown begins", "Last class over. Time to unwind"],
    ["Week cleared. Happy weekend", "Friday's out — weekend mode on", "A whole week's work. Treat yourself", "Classes done. Where to this weekend?"],
    ["Classes done. Relax tonight", "Long day — get a good meal", "Class dismissed. The evening is yours", "All wrapped up. Sleep early"],
    ["All classes done. Nice work", "Today: cleared", "Class dismissed. The rest of the day is yours", "Done for the day. Go do something fun"],
]
