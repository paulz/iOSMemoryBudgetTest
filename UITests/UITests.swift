//
//  UITests.swift
//  UITests
//
//  Created by Paul Zabelin on 7/4/19.
//  Copyright © 2019 Jan Ilavsky. All rights reserved.
//

import XCTest

class UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
    }

    func testOutOfMemory() {
        app.buttons["Start New Test"].tap()
        XCTAssert(app.wait(for: .notRunning, timeout: 60), "app should stop running")
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 30), "app should restart")
        add(screenshot(name: "after relaunch"))
    }

    func screenshot(name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}
