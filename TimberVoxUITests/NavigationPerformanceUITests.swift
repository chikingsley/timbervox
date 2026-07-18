import XCTest

final class NavigationPerformanceUITests: XCTestCase {
  @MainActor
  func testHomeToHistoryPresentation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--skip-onboarding"]
    app.launch()
    continueAfterFailure = false

    let viewHistory = app.buttons["home.section.view-history"]
    let historyContent = app.descendants(matching: .any)["history.content"]
    XCTAssertTrue(viewHistory.waitForExistence(timeout: 3))
    app.activate()

    let navigationMetric = XCTOSSignpostMetric(
      subsystem: "studio.peacockery.timbervox",
      category: "navigation",
      name: "HomeToHistory"
    )
    let queryMetric = XCTOSSignpostMetric(
      subsystem: "studio.peacockery.timbervox",
      category: "navigation",
      name: "HistoryQuery"
    )
    let options = XCTMeasureOptions()
    options.iterationCount = 5

    measure(metrics: [navigationMetric, queryMetric], options: options) {
      app.activate()
      viewHistory.click()
      XCTAssertTrue(historyContent.waitForExistence(timeout: 2))

      app.buttons["sidebar.home"].click()
      XCTAssertTrue(viewHistory.waitForExistence(timeout: 2))
    }
  }
}
