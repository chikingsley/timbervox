enum ModeTextTransformPreset: String, CaseIterable, Codable, Identifiable, Sendable {
  case voiceToText = "voice_to_text"
  case superPrompt = "super"
  case message
  case note
  case email
  case meeting
  case custom

  var id: String { rawValue }

  static let referenceOrder: [Self] = [
    .superPrompt,
    .voiceToText,
    .message,
    .email,
    .note,
    .meeting,
    .custom,
  ]

  var label: String {
    switch self {
    case .voiceToText: "Voice to Text"
    case .superPrompt: "Super"
    case .message: "Message"
    case .note: "Note"
    case .email: "Mail"
    case .meeting: "Meeting Summary"
    case .custom: "Custom"
    }
  }

  var systemImage: String {
    switch self {
    case .voiceToText: "mic"
    case .superPrompt: "sparkles"
    case .message: "message"
    case .note: "note.text"
    case .email: "envelope"
    case .meeting: "person.2"
    case .custom: "square.on.square"
    }
  }

  var usesTextTransform: Bool {
    self != .voiceToText
  }

  var explanation: String {
    switch self {
    case .voiceToText:
      "Transcribes speech directly. No language model or post-processing is used."
    case .superPrompt:
      "Conservatively corrects dictation using all available app, selection, clipboard, and screen context."
    case .message:
      "Cleans dictation into a concise message without answering it or adding new content."
    case .note:
      "Organizes the dictated content into structured notes using only what you said."
    case .email:
      "Formats the dictation as an email with a greeting, clear body, and sign-off."
    case .meeting:
      "Turns a meeting transcript into a structured summary with decisions and action items."
    case .custom:
      "Runs your saved prompt with only the context sources you choose below."
    }
  }

  var usesAllAvailableContext: Bool {
    usesTextTransform && self != .custom
  }

  var allowsContextSelection: Bool {
    self == .custom
  }

  var presetID: TextTransformPresetID? {
    switch self {
    case .voiceToText: nil
    case .superPrompt: .superPrompt
    case .message: .messagePrompt
    case .note: .notePrompt
    case .email: .emailPrompt
    case .meeting: .meetingPrompt
    case .custom: .customPrompt
    }
  }

  func preset(customInstructions: String) -> TextTransformPreset? {
    guard let presetID else { return nil }
    if presetID == .customPrompt {
      return .custom(customInstructions)
    }
    return TextTransformPreset.builtIn(id: presetID)
  }
}
