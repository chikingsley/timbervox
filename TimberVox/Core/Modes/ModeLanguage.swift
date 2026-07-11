import Foundation

struct ModeLanguageOption: Equatable, Hashable, Identifiable, Sendable {
  var code: String?

  var id: String { code ?? ModeLanguageLabel.automaticID }
  var name: String { ModeLanguageLabel.name(for: code) }
}

enum ModeLanguageLabel {
  static let automaticID = "automatic"

  static func name(for code: String?) -> String {
    guard let code else { return "Automatic" }
    if code == "multi" {
      return "Multilingual"
    }
    return Locale.current.localizedString(forLanguageCode: code)
      ?? fallbackNames[code]
      ?? code.uppercased()
  }

  private static let fallbackNames: [String: String] = [
    "ast": "Asturian",
    "ba": "Bashkir",
    "ceb": "Cebuano",
    "fil": "Filipino",
    "haw": "Hawaiian",
    "ht": "Haitian Creole",
    "jw": "Javanese",
    "kea": "Kabuverdianu",
    "nso": "Northern Sotho",
    "su": "Sundanese",
    "yue": "Cantonese",
  ]
}
