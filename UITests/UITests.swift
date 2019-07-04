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
    }
}
