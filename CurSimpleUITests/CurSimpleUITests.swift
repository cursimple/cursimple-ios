import XCTest

final class CurSimpleUITests: XCTestCase {

    func testLaunchShowsScheduleTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["课表"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }

    func testAddCourseThroughEditor() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        // Open the course editor from the toolbar plus button.
        let addButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS '添加'")).firstMatch
        if addButton.exists {
            addButton.tap()
        } else {
            app.buttons.matching(NSPredicate(format: "label CONTAINS '添加课程'")).firstMatch.tap()
        }

        let titleField = app.textFields["课程名称"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("高等数学")

        app.buttons["保存"].tap()

        // The new course should appear on the week grid.
        XCTAssertTrue(app.staticTexts["高等数学"].waitForExistence(timeout: 5))
    }

    func testSettingsTabsAndAppearance() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()

        XCTAssertTrue(app.staticTexts["学期"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["节次作息"].exists)
        XCTAssertTrue(app.staticTexts["外观"].exists)
    }
}
