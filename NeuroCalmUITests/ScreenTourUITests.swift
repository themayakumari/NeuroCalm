//
//  ScreenTourUITests.swift
//  NeuroCalmUITests
//
//  Not a real regression test — walks each tab and attaches a screenshot,
//  used to visually verify the Exhale-styled redesign end to end.
//

import XCTest

final class ScreenTourUITests: XCTestCase {

    func testTourAllTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()

        // Let the sidebar/tab bar finish its initial layout pass before the
        // first tap — tapping immediately after launch can miss on iPad.
        sleep(1)
        capture(app, name: "01-home")

        let tabs = ["Breathe", "Relax", "Planner", "Assistant", "Progress"]
        for (index, tab) in tabs.enumerated() {
            tapSection(app, label: tab)
            sleep(2)
            capture(app, name: "0\(index + 2)-\(tab.lowercased())")
        }
    }

    /// Sends a message to the Assistant and captures the conversational reply.
    func testAssistantConversation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        tapSection(app, label: "Assistant")
        sleep(1)
        let chip = app.buttons["I have a test tomorrow"]
        if chip.waitForExistence(timeout: 3) { chip.tap() }
        sleep(3) // let the typing indicator resolve into a reply
        capture(app, name: "assistant-chat")
    }


    /// Reproduces the reported bug: send a message, leave the Assistant tab,
    /// come back — the conversation must still be there (now persisted), and
    /// the new Conversations list must be reachable.
    func testAssistantPersistsAcrossNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)

        tapSection(app, label: "Assistant")
        sleep(1)
        let field = app.textFields["assistantInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        // Tap and wait for keyboard focus before typing (avoids a focus race).
        field.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) {
            field.tap()
            _ = app.keyboards.element.waitForExistence(timeout: 2)
        }
        field.typeText("Exam stress test")
        app.buttons["assistantSend"].tap()
        sleep(3) // user bubble + reply
        XCTAssertTrue(app.staticTexts["Exam stress test"].waitForExistence(timeout: 3),
                      "message should appear after sending")
        capture(app, name: "persist-01-before-leaving")

        // Leave the Assistant and come back.
        tapSection(app, label: "Progress")
        sleep(1)
        tapSection(app, label: "Assistant")
        sleep(1)
        capture(app, name: "persist-02-after-return")

        // The message we sent must survive the round-trip.
        XCTAssertTrue(app.staticTexts["Exam stress test"].waitForExistence(timeout: 3),
                      "conversation should persist after navigating away and back")

        // Open the Conversations history list.
        let history = app.buttons["Conversations"]
        if history.waitForExistence(timeout: 3) { history.tap() }
        sleep(1)
        capture(app, name: "persist-03-history-list")
    }

    /// Captures the Assistant with its second (conversations) sidebar on iPad.
    func testAssistantSecondSidebar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        tapSection(app, label: "Assistant")
        sleep(1)
        // Send one message so there's a titled conversation in the sidebar.
        let field = app.textFields["assistantInput"]
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("Sidebar demo")
            app.buttons["assistantSend"].tap()
            sleep(3)
        }
        capture(app, name: "assistant-ipad-sidebar")
    }

    /// MVP: captures the crisis Support screen and confirms Challenges shows no
    /// team ("With friends") section when the feature flag is off.
    func testMVPSupportAndChallenges() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        // Confirm the always-present support card exists on Home.
        let supportCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Need to talk")).firstMatch
        var tries = 0
        while !supportCard.exists && tries < 6 { app.swipeUp(); sleep(1); tries += 1 }
        XCTAssertTrue(supportCard.exists, "Home should show the support card")
        app.swipeDown(); sleep(1)   // back to top for the Settings gear

        // Open the Support screen via Settings (deterministic path).
        let gear = app.buttons["Settings"]
        if gear.waitForExistence(timeout: 3) { gear.tap() }
        sleep(1)
        let getHelp = app.buttons["Get help now"]
        if getHelp.waitForExistence(timeout: 3) { getHelp.tap() }
        XCTAssertTrue(app.staticTexts["You're not alone"].waitForExistence(timeout: 3),
                      "support screen should open")
        sleep(1)
        capture(app, name: "mvp-support")

        // Back out to Home for the next step.
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)

        // Challenges should have no "With friends" section in the MVP.
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Set a calm goal")).firstMatch
        if card.waitForExistence(timeout: 3) { card.tap() }
        sleep(1)
        capture(app, name: "mvp-challenges")
        XCTAssertFalse(app.staticTexts["With friends"].exists,
                       "team section should be hidden in the MVP")
    }

    /// Captures the Practices library and an "About this practice" detail.
    func testPracticesLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        let practices = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Learn the calming")).firstMatch
        XCTAssertTrue(practices.waitForExistence(timeout: 5))
        practices.tap()
        // Wait for the library (a category header) before capturing.
        let header = app.staticTexts["Breathing techniques"]
        if !header.waitForExistence(timeout: 4) {
            practices.tap()
            _ = header.waitForExistence(timeout: 4)
        }
        sleep(1)
        capture(app, name: "practices-library")
        let firstRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Nadi")).firstMatch
        if firstRow.waitForExistence(timeout: 3) { firstRow.tap() }
        sleep(1)
        capture(app, name: "practice-detail")
        // Back to the library, then open Shavasana to check its linked audio.
        let back = app.navigationBars.buttons["Practices"]
        if back.waitForExistence(timeout: 3) { back.tap() }
        sleep(1)
        app.swipeUp()
        sleep(1)
        let shav = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Shavasana")).firstMatch
        if shav.waitForExistence(timeout: 3) { shav.tap() }
        sleep(1)
        app.swipeUp()   // scroll to the Guided audio list
        sleep(1)
        capture(app, name: "shavasana-detail")
    }


    /// Captures the Calm Ring on Home and the Badges grid.
    func testCalmRingAndBadges() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        capture(app, name: "home-ring")
        tapSection(app, label: "Progress")
        sleep(1)
        let badges = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "earned")).firstMatch
        if badges.waitForExistence(timeout: 4) { badges.tap() }
        sleep(1)
        capture(app, name: "badges")
    }


    /// Captures the Challenges screen and starting one.
    func testChallenges() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Set a calm goal")).firstMatch
        if card.waitForExistence(timeout: 5) { card.tap() }
        sleep(1)
        capture(app, name: "challenges")
        let start = app.buttons["Start"].firstMatch
        if start.waitForExistence(timeout: 3) { start.tap() }
        sleep(1)
        capture(app, name: "challenges-active")
        app.swipeUp(); app.swipeUp()
        sleep(1)
        capture(app, name: "challenges-friends")
    }


    /// Captures the iPad sidebar (should list Practices + Challenges).
    func testIPadSidebar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(2)
        capture(app, name: "ipad-sidebar")
    }


    /// Opens the Progress share sheet.
    func testShare() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        tapSection(app, label: "Progress")
        sleep(1)
        // Scroll the social share row into view and capture the branded tiles.
        let fbTile = app.buttons["Share to Facebook"]
        var tries = 0
        while !fbTile.exists && tries < 6 { app.swipeUp(); sleep(1); tries += 1 }
        if fbTile.exists { app.swipeUp(); sleep(1) }   // lift the row clear of the tab bar
        capture(app, name: "share-tiles")
        // Tapping a network opens the iOS share sheet with the streak card.
        if fbTile.waitForExistence(timeout: 2) {
            fbTile.tap()
            sleep(2)
            capture(app, name: "share-sheet")
        }
    }

    /// Captures the heart visualization (cycles Circle → Lungs → Heart).
    func testHeartVisualization() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        tapSection(app, label: "Breathe")
        sleep(1)

        func tapViz(_ label: String) {
            let b = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            if b.waitForExistence(timeout: 3) { b.tap() }
            sleep(1)
        }
        tapViz("Circle")   // → Lungs
        tapViz("Lungs")    // → Heart
        capture(app, name: "heart-ready")

        let start = app.buttons["Start"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        sleep(3)
        capture(app, name: "heart-running")
    }

    /// Captures the signed-out login screen (no UI-TESTING bypass).
    func testLoginScreen() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        capture(app, name: "login")
    }

    /// Captures the breathing selectors and the lungs visualization mid-inhale.
    func testLungsVisualization() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        tapSection(app, label: "Breathe")
        sleep(1)
        capture(app, name: "breathe-selectors")

        // Switch the visualization from Circle to Lungs.
        let vizButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Circle")).firstMatch
        XCTAssertTrue(vizButton.waitForExistence(timeout: 3), "visualization chip should exist")
        vizButton.tap()
        sleep(1)
        // Confirm it flipped to Lungs before starting.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Lungs")).firstMatch.waitForExistence(timeout: 3))
        capture(app, name: "lungs-ready")   // resting lungs, before Start

        let start = app.buttons["Start"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        sleep(2) // into the inhale — sage air filling
        capture(app, name: "lungs-inhale")
        sleep(3) // early exhale — ember air leaving, still visible
        capture(app, name: "lungs-exhale")
    }

    /// Landscape-only smoke check (diagnostic — not part of the regular tour).
    /// Logs real logical frame sizes (unaffected by the simulator's
    /// screenshot-capture orientation bug) alongside screenshots.
    func testLandscapeHomeAndBreathe() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        sleep(1)
        capture(app, name: "landscape-01-home")
        logFrames(app, name: "landscape-01-home-frames")

        for tab in ["Planner", "Progress", "Breathe"] {
            tapSection(app, label: tab)
            sleep(2)
            capture(app, name: "landscape-\(tab.lowercased())")
        }

        XCUIDevice.shared.orientation = .portrait
    }

    private func logFrames(_ app: XCUIApplication, name: String) {
        var lines = [String]()
        lines.append("device orientation: \(XCUIDevice.shared.orientation.rawValue)")
        lines.append("screen bounds: \(XCUIScreen.main.screenshot().image.size)")
        lines.append("app frame: \(app.frame)")
        lines.append("window frame: \(app.windows.firstMatch.frame)")
        let text = lines.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// iPhone shows a bottom tab bar; iPad (regular width) shows a
    /// `List(selection:)` sidebar instead, whose rows don't reliably surface
    /// under one specific element type across iOS versions — so match on
    /// the exact label across *any* element type rather than guessing.
    /// Deliberately doesn't hard-fail: one misfired tap shouldn't blank out
    /// every screenshot after it when this is a visual smoke check, not a
    /// correctness test.
    private func tapSection(_ app: XCUIApplication, label: String) {
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.waitForExistence(timeout: 3) {
            // Tab-bar taps can no-op right after launch if the control isn't
            // hittable yet, or if the first tap only gives focus. Wait until
            // hittable and retry until the tab actually selects.
            for _ in 0..<5 {
                if tabBarButton.isHittable { tabBarButton.tap() }
                if tabBarButton.isSelected { return }
                usleep(400_000)
            }
            return
        }
        let predicate = NSPredicate(format: "label == %@", label)
        let match = app.descendants(matching: .any).matching(predicate).firstMatch
        if match.waitForExistence(timeout: 5) {
            match.tap()
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
