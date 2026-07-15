import Foundation

enum TimberVoxJSONCoding {
  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom(decodeDate)
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom(encodeDate)
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
  }

  private static func decodeDate(from decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
      return date
    }
    let standardFormatter = ISO8601DateFormatter()
    standardFormatter.formatOptions = [.withInternetDateTime]
    guard let date = standardFormatter.date(from: value) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid ISO-8601 date: \(value)"
      )
    }
    return date
  }

  private static func encodeDate(_ date: Date, to encoder: Encoder) throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var container = encoder.singleValueContainer()
    try container.encode(formatter.string(from: date))
  }
}
