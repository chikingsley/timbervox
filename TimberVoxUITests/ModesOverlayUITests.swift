import XCTest

final class ModesOverlayUITests: XCTestCase {
  @MainActor
  func testVoiceModelComboboxIsPortaledSearchableAndDismissible() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--skip-onboarding"]
    app.launch()
    app.buttons["sidebar.modes"].click()

    let activeMode = app.descendants(matching: .any)["mode.list.active"]
    XCTAssertTrue(activeMode.waitForExistence(timeout: 5))
    activeMode.click()

    let trigger = app.descendants(matching: .any)["mode.voice-model"]
    XCTAssertTrue(trigger.waitForExistence(timeout: 5))
    let selectedModelName = try XCTUnwrap(trigger.value as? String)
    trigger.click()

    let search = app.textFields["Search models"]
    XCTAssertTrue(search.waitForExistence(timeout: 3))
    XCTAssertTrue(search.isHittable)
    XCTAssertGreaterThanOrEqual(
      search.frame.minY,
      trigger.frame.maxY,
      "The model overlay must open below its trigger instead of covering it."
    )

    let selectedModel = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH[c] %@", selectedModelName)
    ).firstMatch
    XCTAssertTrue(selectedModel.isSelected)
    XCTAssertFalse(app.buttons["Add favorite"].firstMatch.isSelected)

    search.typeText("Scribe")
    let result = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH[c] %@", "Scribe")
    ).firstMatch
    XCTAssertTrue(result.waitForExistence(timeout: 3))
    XCTAssertTrue(result.isHittable)

    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(search.waitForNonExistence(timeout: 2))

    trigger.click()
    XCTAssertTrue(search.waitForExistence(timeout: 2))
    app.buttons["sidebar.home"].click()
    XCTAssertTrue(search.waitForNonExistence(timeout: 2))
    XCTAssertTrue(app.buttons["home.section.view-history"].waitForExistence(timeout: 3))
  }
}
