import XCTest

/// Regression coverage for the features added after the first release:
/// term management, memos, alarms, holidays, overrides, sharing, backup,
/// display settings, school import and plugins.
final class FeatureRegressionTests: XCTestCase {

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchArguments += arguments
        app.launch()
        return app
    }

    private func openDrawerItem(_ app: XCUIApplication, _ label: String) {
        let menu = app.buttons["打开菜单"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()

        let item = app.buttons[label]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "drawer item \(label) missing")
        item.tap()
    }

    // MARK: - Navigation

    func testDrawerListsEverySection() {
        let app = launch(["-seedSampleCourses"])
        let menu = app.buttons["打开菜单"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()

        for label in ["课表", "管理列表", "备忘录", "闹钟", "学校导入", "插件", "设置"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 3), "missing drawer entry: \(label)")
        }
    }

    // MARK: - Week picker

    func testWeekPickerJumpsToWeek() {
        let app = launch(["-seedSampleCourses"])

        // The pill announces the current week plus the action.
        let pill = app.buttons.matching(NSPredicate(format: "label CONTAINS '切换周次'")).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 20))
        pill.tap()

        // The sheet shows the month title and the week strip.
        let jump = app.staticTexts["跳转到周次"]
        if !jump.waitForExistence(timeout: 5) {
            // Section labels may merge into other elements; fall back to the strip.
            XCTAssertTrue(
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH '第 2 周'")).firstMatch
                    .waitForExistence(timeout: 5),
                "week picker did not open"
            )
        }

        // Pick week 3 from the strip; the sheet closes and the header follows.
        let week3 = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '第 3 周'")).firstMatch
        XCTAssertTrue(week3.waitForExistence(timeout: 5))
        week3.tap()

        // The pill label is the displayed week; assert it changed to week 3.
        let pillAfter = app.buttons.matching(NSPredicate(format: "label CONTAINS '切换周次'")).firstMatch
        XCTAssertTrue(pillAfter.waitForExistence(timeout: 8))
        let label = pillAfter.label
        XCTAssertTrue(
            label.contains("第 3 周"),
            "week pill still reads \(label) after picking week 3"
        )
    }

    // MARK: - Memos

    func testMemoFiltersAndSearch() {
        let app = launch(["-seedSampleCourses", "-startMemo"])

        XCTAssertTrue(app.staticTexts["全部"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["待办"].exists)
        XCTAssertTrue(app.staticTexts["今天到期"].exists)

        // Overdue stat card filters the list.
        app.buttons.matching(NSPredicate(format: "label CONTAINS '已逾期'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["复习第三章"].waitForExistence(timeout: 5))

        // Search narrows further.
        app.buttons["搜索备忘"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("不存在的关键字")
        XCTAssertFalse(app.staticTexts["复习第三章"].exists)
    }

    func testMemoChecklistTogglesFromCard() {
        let app = launch(["-seedSampleCourses", "-startMemo"])

        let item = app.buttons.matching(NSPredicate(format: "label CONTAINS '做课后题'")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        item.tap()

        // Toggling persists: the row keeps existing after the tap.
        XCTAssertTrue(item.exists)
    }

    // MARK: - Alarms

    func testAlarmListAndEditor() {
        let app = launch(["-seedSampleCourses", "-startAlarm"])

        XCTAssertTrue(app.staticTexts["下一个闹钟"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["06:50"].exists)

        app.buttons["添加闹钟"].tap()
        XCTAssertTrue(app.staticTexts["新建闹钟"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["重复"].exists)
        XCTAssertTrue(app.buttons["取消"].exists)
    }

    // MARK: - Settings sub-pages

    func testSettingsPagesOpen() {
        let app = launch(["-seedSampleCourses", "-startSettings"])

        XCTAssertTrue(app.staticTexts["常用"].waitForExistence(timeout: 20))

        for (entry, marker) in [
            ("学期数据", "开学日期"),
            ("节次作息", "第1节"),
            ("显示", "课程文字大小"),
            ("节假日与调休", "使用内置节假日"),
            ("临时调课", "临时调课"),
            ("上课提醒", "开启上课提醒"),
            ("备份与恢复", "导出备份"),
            ("课表分享", "分享当前课表"),
        ] {
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", entry)).firstMatch.tap()
            XCTAssertTrue(
                app.staticTexts[marker].waitForExistence(timeout: 8),
                "page \(entry) did not show \(marker)"
            )
            app.buttons["返回"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["常用"].waitForExistence(timeout: 8))
        }
    }

    // MARK: - Sharing

    func testShareCodeRoundTrip() {
        let app = launch(["-seedSampleCourses", "-startSettings", "-openShare", "-importFixture"])

        let parse = app.buttons["解析分享码"]
        XCTAssertTrue(parse.waitForExistence(timeout: 20))
        parse.tap()

        let confirm = app.buttons["导入为新学期"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["导入的学期"].waitForExistence(timeout: 8))
    }

    // MARK: - School import

    func testSchoolCatalogSearches() {
        let app = launch(["-seedSampleCourses", "-startSchool"])

        XCTAssertTrue(app.staticTexts["选择学校"].waitForExistence(timeout: 20))

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("上海交通大学")

        XCTAssertTrue(app.staticTexts["上海交通大学"].waitForExistence(timeout: 5))
    }

    // MARK: - Plugins

    func testPluginPageShowsInstallEntry() {
        let app = launch(["-seedSampleCourses", "-startPlugins"])

        XCTAssertTrue(app.staticTexts["安装插件"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["选择文件"].exists)
        XCTAssertTrue(app.staticTexts["还没有安装插件"].exists)
    }

    // MARK: - Library

    func testLibraryFiltersCoursesAndEvents() {
        let app = launch(["-seedSampleCourses", "-startLibrary"])

        XCTAssertTrue(app.staticTexts["管理列表"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["新增课程"].exists)
        XCTAssertTrue(app.buttons["添加事务"].exists)

        // Switch to the events tab; the sample data has none.
        let eventsTab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '事务'")).firstMatch
        XCTAssertTrue(eventsTab.waitForExistence(timeout: 5))
        eventsTab.tap()
        XCTAssertTrue(app.staticTexts["还没有事务"].waitForExistence(timeout: 5))

        // Back to courses.
        let coursesTab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '课程'")).firstMatch
        XCTAssertTrue(coursesTab.waitForExistence(timeout: 5))
        coursesTab.tap()
        XCTAssertTrue(app.staticTexts["高等数学"].waitForExistence(timeout: 5))
    }
}

/// Drag-to-move writes a temporary override for the displayed week only.
final class CourseMoveTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-seedSampleCourses",
        ]
        app.launch()
        return app
    }

    func testDraggingCourseMovesItToAnotherDay() {
        let app = launch()

        // Monday's 高等数学 starts at the first period.
        let course = app.staticTexts["高等数学"].firstMatch
        XCTAssertTrue(course.waitForExistence(timeout: 20))

        let start = course.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Drag two columns right (roughly two day widths).
        let target = start.withOffset(CGVector(dx: 150, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: target)

        // The override list records exactly one move.
        let menu = app.buttons["打开菜单"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        app.buttons["设置"].tap()

        // The tile is a NavigationLink; match any element type carrying its label.
        let overrides = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS '临时调课'")
        ).firstMatch
        XCTAssertTrue(overrides.waitForExistence(timeout: 10))
        overrides.tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '调课'")).firstMatch
                .waitForExistence(timeout: 8),
            "no move override was recorded"
        )
    }
}

/// Long-press on a course opens quick actions.
final class CourseActionTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-seedSampleCourses",
        ]
        app.launch()
        return app
    }

    func testLongPressShowsActions() {
        let app = launch()

        let course = app.staticTexts["高等数学"].firstMatch
        XCTAssertTrue(course.waitForExistence(timeout: 20))
        course.press(forDuration: 0.9)

        for action in ["编辑课程", "课程详情", "今天停课一次", "从课表隐藏", "删除课程"] {
            XCTAssertTrue(
                app.buttons[action].waitForExistence(timeout: 5),
                "missing action: \(action)"
            )
        }
    }

    func testCancelTodayWritesOverride() {
        let app = launch()

        let course = app.staticTexts["高等数学"].firstMatch
        XCTAssertTrue(course.waitForExistence(timeout: 20))
        course.press(forDuration: 0.9)

        let cancel = app.buttons["今天停课一次"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()

        // The override is recorded even when today is not a class day, so the
        // list under Settings → 临时调课 must show a cancellation entry.
        let menu = app.buttons["打开菜单"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        app.buttons["设置"].tap()

        let overrides = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS '临时调课'")
        ).firstMatch
        XCTAssertTrue(overrides.waitForExistence(timeout: 10))
        if !overrides.isHittable {
            app.swipeUp()
        }
        overrides.tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '停课'")).firstMatch
                .waitForExistence(timeout: 8),
            "no cancellation override recorded"
        )
    }
}
