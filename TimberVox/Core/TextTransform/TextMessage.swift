import Foundation

public enum TextMessageRole: String, Codable, Equatable, Sendable {
  case system
  case user
  case assistant
}

public struct TextMessage: Codable, Equatable, Sendable {
  public let role: TextMessageRole
  public let content: String

  public init(role: TextMessageRole, content: String) {
    self.role = role
    self.content = content
  }
}
