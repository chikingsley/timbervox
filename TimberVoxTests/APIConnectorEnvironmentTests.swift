import XCTest

@testable import TimberVox

final class APIConnectorEnvironmentTests: XCTestCase {
  func testExplicitAPIKeyAuthorizesDebugRequest() async throws {
    let authorization = APIConnectorAuthorization(apiKey: "test-key")
    let request = URLRequest(url: URL(string: "https://example.com/v1/models")!)

    let authorized = try await authorization.authorize(request)

    XCTAssertEqual(
      authorized.value(forHTTPHeaderField: "Authorization"),
      "Bearer test-key"
    )
  }

  func testMissingExplicitAPIKeyIsRejected() async {
    let authorization = APIConnectorAuthorization(apiKey: nil)
    let request = URLRequest(url: URL(string: "https://example.com/v1/models")!)

    do {
      _ = try await authorization.authorize(request)
      XCTFail("Expected missing Debug credentials to be rejected")
    } catch let error as APIConnectorError {
      guard case .configuration = error else {
        XCTFail("Expected configuration error, received: \(error)")
        return
      }
    } catch {
      XCTFail("Expected APIConnectorError, received: \(error)")
    }
  }

  func testLabEnvironmentUsesVoiceLab() throws {
    XCTAssertEqual(
      try APIConnector.baseURL(environment: "lab"),
      APIConnector.labBaseURL
    )
  }

  func testProductionEnvironmentUsesVoiceProduction() throws {
    XCTAssertEqual(
      try APIConnector.baseURL(environment: "production"),
      APIConnector.productionBaseURL
    )
  }

  func testEnvironmentParsingIsWhitespaceAndCaseInsensitive() throws {
    XCTAssertEqual(
      try APIConnector.baseURL(environment: " LAB "),
      APIConnector.labBaseURL
    )
  }

  func testUnsupportedEnvironmentIsRejected() {
    XCTAssertThrowsError(try APIConnector.baseURL(environment: "staging"))
    XCTAssertThrowsError(try APIConnector.baseURL(environment: nil))
  }
}
