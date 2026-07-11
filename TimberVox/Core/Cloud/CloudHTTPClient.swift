import Foundation

enum TimberVoxCloudError: LocalizedError {
  case configuration(String)
  case emptyResult
  case httpStatus(Int)
  case invalidResponse
  case jobFailed(String)
  case realtimeFailed(String)
  case timedOut
  case uploadFailed(String)

  var errorDescription: String? {
    switch self {
    case .configuration(let message): message
    case .emptyResult: "The transcription came back empty."
    case .httpStatus(let code): "Server error (HTTP \(code))."
    case .invalidResponse: "The server response was not valid."
    case .jobFailed(let reason): "The server could not transcribe: \(reason)"
    case .realtimeFailed(let reason): "Realtime transcription failed: \(reason)"
    case .timedOut: "Transcription timed out."
    case .uploadFailed(let reason): "Audio upload failed after retrying: \(reason)"
    }
  }

  var isTransientUploadFailure: Bool {
    switch self {
    case .httpStatus(let code):
      [408, 425, 429, 500, 502, 503, 504].contains(code)
    default:
      false
    }
  }
}

struct CloudHTTPClient: Sendable {
  static let productionBaseURL = URL(string: "https://timbervox.peacockery.studio")!

  var authorization: CloudAuthorization = .shared
  var baseURL: URL
  var session: URLSession = .shared

  func get<Response: Decodable>(
    path: String,
    authorized: Bool = true
  ) async throws -> Response {
    var request = makeRequest(path: path)
    request.httpMethod = "GET"
    return try await performJSON(request, authorized: authorized)
  }

  func post<Body: Encodable, Response: Decodable>(
    path: String,
    body: Body
  ) async throws -> Response {
    var request = makeRequest(path: path)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try CloudCoders.encode(body)
    return try await performJSON(request, authorized: true)
  }

  func upload(
    fileAt fileURL: URL, to url: URL, headers: [String: String], timeout: TimeInterval
  ) async throws -> String? {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.timeoutInterval = timeout
    let (_, response) = try await session.upload(for: request, fromFile: fileURL)
    try validate(response)
    return (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
  }

  func upload(data: Data, to url: URL, headers: [String: String], timeout: TimeInterval) async throws -> String? {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.timeoutInterval = timeout
    let (_, response) = try await session.upload(for: request, from: data)
    try validate(response)
    return (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
  }

  private func performJSON<Response: Decodable>(
    _ request: URLRequest,
    authorized: Bool
  ) async throws -> Response {
    let prepared = try await prepare(request, authorized: authorized)
    let (data, response) = try await session.data(for: prepared)
    try validate(response)
    return try CloudCoders.decode(Response.self, from: data)
  }

  private func prepare(
    _ request: URLRequest,
    authorized: Bool
  ) async throws -> URLRequest {
    guard authorized else { return request }
    var prepared = request
    let credential = try await authorization.credential()
    prepared.setValue(
      "Bearer \(credential)",
      forHTTPHeaderField: "Authorization"
    )
    return prepared
  }

  private func makeRequest(path: String) -> URLRequest {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func validate(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw TimberVoxCloudError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw TimberVoxCloudError.httpStatus(httpResponse.statusCode)
    }
  }
}

enum CloudCoders {
  static func encode<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return try encoder.encode(value)
  }

  static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(type, from: data)
  }
}
