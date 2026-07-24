import XCTest

final class SidebarResponsivenessUITests: XCTestCase {
  @MainActor
  func testTooltipPresentationDoesNotBlockSidebarToggle() async throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--skip-onboarding"]
    app.launch()

    let trigger = app.buttons["sidebar.toggle"]
    XCTAssertTrue(trigger.waitForExistence(timeout: 5))
    let initialValue = try XCTUnwrap(trigger.value as? String)
    let expectedValue = initialValue == "Expanded" ? "Collapsed" : "Expanded"

    trigger.hover()
    try await Task.sleep(for: .milliseconds(300))
    trigger.click()

    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline, trigger.value as? String != expectedValue {
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTAssertEqual(trigger.value as? String, expectedValue)
  }
}
