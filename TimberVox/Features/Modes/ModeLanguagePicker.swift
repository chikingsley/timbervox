import SwiftUI

struct ModeLanguagePicker: View {
  @Binding var selection: String
  let supportedLanguages: [String]
  let supportsAutomaticLanguage: Bool

  private var options: [ModeLanguageOption] {
    supportedLanguages
      .map { ModeLanguageOption(code: $0) }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  var body: some View {
    Picker("Language", selection: $selection) {
      if supportsAutomaticLanguage {
        Text("Automatic").tag(ModeLanguageLabel.automaticID)
      }
      ForEach(options) { option in
        Text(option.name).tag(option.code ?? ModeLanguageLabel.automaticID)
      }
    }
  }
}
