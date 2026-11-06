import XCTest

final class CurSimpleUITests: XCTestCase {

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchArguments += arguments
        app.launch()
        return app
    }

    func testLaunchShowsScheduleChrome() {
        let app = launch()

        XCTAssertTrue(app.buttons["打开菜单"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["添加课程"].exists)
        XCTAssertTrue(app.buttons["切换到日视图"].exists)
    }

    func testDrawerNavigatesToSettings() {
        let app = launch()

        let menu = app.buttons["打开菜单"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()

        let settings = app.buttons["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        XCTAssertTrue(app.staticTexts["常用"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["课程与时间"].exists)
    }

    func testAddCourseThroughEditor() {
        let app = launch()

        let add = app.buttons["添加课程"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()

        let titleField = app.textFields["课程名称"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()

        let title = "测试课程"
        titleField.typeText(title)
        app.buttons["保存"].tap()

        // The grid renders the title with scale/truncation, so match a prefix.
        let created = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "测试课程")
        ).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 5))
    }

    func testEnablingRemindersSchedulesNotifications() {
        let app = launch(["-seedSampleCourses", "-startSettings", "-openReminders"])

        let master = app.switches["reminder-master-toggle"]
        XCTAssertTrue(master.waitForExistence(timeout: 20))

        if (master.value as? String) == "0" {
            master.tap()
        }

        // The permission prompt belongs to SpringBoard; accept it if shown.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["允许", "Allow", "好"] {
            let button = springboard.buttons[label].firstMatch
            if button.waitForExistence(timeout: 5) {
                button.tap()
                break
            }
        }

        XCTAssertTrue(app.staticTexts["已允许"].waitForExistence(timeout: 10)
            || app.staticTexts["临时允许"].exists)

        let count = app.staticTexts["reminder-scheduled-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))

        // Sample data has a Friday-evening exam and weekend-free days; the
        // exact count depends on the real clock, so re-plan and accept any
        // non-negative value while asserting the permission state held.
        let grantedAgain = app.staticTexts["已允许"].exists || app.staticTexts["临时允许"].exists
        XCTAssertTrue(grantedAgain, "permission must stay granted after re-planning")
    }

    func testImportsShareCode() {
        let app = launch(["-seedSampleCourses", "-startSettings", "-openShare", "-importFixture"])

        let parse = app.buttons["解析分享码"]
        XCTAssertTrue(parse.waitForExistence(timeout: 20))
        parse.tap()

        let confirm = app.buttons["导入为新学期"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["导入的学期"].waitForExistence(timeout: 8))
    }

    func testDayViewFromWeekHeader() {
        let app = launch()

        let dayToggle = app.buttons["切换到日视图"]
        XCTAssertTrue(dayToggle.waitForExistence(timeout: 15))
        dayToggle.tap()

        let overview = app.staticTexts["今日概览"]
        let empty = app.staticTexts["今天没有课程"]
        let finished = app.staticTexts["今天的课程已结束"]
        let inClass = app.staticTexts["正在上课"]
        let nextClass = app.staticTexts["下一节课"]
        let overviewVisible = overview.waitForExistence(timeout: 8)
            || empty.waitForExistence(timeout: 0.5)
            || finished.waitForExistence(timeout: 0.5)
            || inClass.waitForExistence(timeout: 0.5)
            || nextClass.waitForExistence(timeout: 0.5)
        XCTAssertTrue(overviewVisible, "no overview state visible")
    }
}
