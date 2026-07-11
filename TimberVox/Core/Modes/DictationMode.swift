import Foundation

enum DictationModeDefaults {
  static let batchModelID = "mistral-voxtral-mini-latest"
  static let realtimeModelID = "mistral-voxtral-mini-transcribe-realtime-2602"
  static let realtimeEnabled = true

  static let legacyBatchModelKey = "cloudBatchTranscriptionModel"
  static let legacyRealtimeModelKey = "cloudRealtimeTranscriptionModel"
  static let legacyRealtimeEnabledKey = "realtimeTranscriptionEnabled"
}

struct DictationMode: Codable, Equatable, Identifiable, Sendable {
  var id: String
  var name: String
  var nameIsCustomized: Bool
  var iconSystemName: String?
  var audioModelID: String
  var languageCode: String?
  var realtimeEnabled: Bool
  var diarizationEnabled: Bool
  var includesSystemAudio: Bool
  var playbackPolicy: PlaybackPolicy
  var textTransformPreset: ModeTextTransformPreset
  var textTransformModelID: String
  var customTextTransformInstructions: String
  var textTransformContextOptions: DictationContextOptions

  var usesTextTransform: Bool {
    textTransformPreset.usesTextTransform
  }

  var effectiveTextTransformContextOptions: DictationContextOptions {
    if textTransformPreset.usesAllAvailableContext {
      return .allAvailable
    }
    if textTransformPreset.allowsContextSelection {
      return textTransformContextOptions
    }
    return .none
  }

  var resolvedIconSystemName: String {
    iconSystemName ?? textTransformPreset.systemImage
  }

  init(
    id: String,
    name: String,
    nameIsCustomized: Bool = false,
    iconSystemName: String? = nil,
    audioModelID: String,
    languageCode: String?,
    realtimeEnabled: Bool,
    diarizationEnabled: Bool,
    includesSystemAudio: Bool = false,
    playbackPolicy: PlaybackPolicy = .keepPlaying,
    textTransformPreset: ModeTextTransformPreset,
    textTransformModelID: String,
    customTextTransformInstructions: String = TextTransformPreset.defaultCustomInstructions,
    textTransformContextOptions: DictationContextOptions = DictationMode.defaultTextTransformContextOptions
  ) {
    self.id = id
    self.name = name
    self.nameIsCustomized = nameIsCustomized
    self.iconSystemName = iconSystemName
    self.audioModelID = audioModelID
    self.languageCode = languageCode
    self.realtimeEnabled = realtimeEnabled
    self.diarizationEnabled = diarizationEnabled
    self.includesSystemAudio = includesSystemAudio
    self.playbackPolicy = playbackPolicy
    self.textTransformPreset = textTransformPreset
    self.textTransformModelID = textTransformModelID
    self.customTextTransformInstructions = customTextTransformInstructions
    self.textTransformContextOptions = textTransformContextOptions
  }

  static let defaultTextTransformContextOptions = DictationContextOptions.allAvailable

  static func defaultMode(defaults: UserDefaults = .standard) -> DictationMode {
    let legacyRealtimeEnabled =
      defaults.object(forKey: DictationModeDefaults.legacyRealtimeEnabledKey) as? Bool
      ?? DictationModeDefaults.realtimeEnabled
    let legacyRealtimeModel = defaults.string(forKey: DictationModeDefaults.legacyRealtimeModelKey)
    let legacyBatchModel = defaults.string(forKey: DictationModeDefaults.legacyBatchModelKey)
    let legacyPublicModel = defaults.string(forKey: "transcriptionModel")

    let migratedAudioModel =
      if legacyRealtimeEnabled,
        legacyRealtimeModel == DictationModeDefaults.realtimeModelID
      {
        DictationModeDefaults.batchModelID
      } else {
        legacyPublicModel ?? legacyBatchModel ?? DictationModeDefaults.batchModelID
      }

    return DictationMode(
      id: "default",
      name: "Default",
      audioModelID: migratedAudioModel,
      languageCode: nil,
      realtimeEnabled: legacyRealtimeEnabled,
      diarizationEnabled: false,
      textTransformPreset: .voiceToText,
      textTransformModelID: "mistral-mistral-small-latest"
    )
  }

  func textTransformRequest(
    rawTranscript: String,
    context: DictationContext? = nil
  ) -> CloudTextTransformRequest? {
    guard usesTextTransform else { return nil }
    guard let preset = textTransformPreset.preset(customInstructions: customTextTransformInstructions) else {
      return nil
    }
    let resolvedContext =
      context
      ?? DictationContext(
        system: SystemContext(language: languageCode.map(ModeLanguageLabel.name(for:)))
      )
    let messages =
      TextTransformPromptBuilder
      .messages(
        preset: preset,
        transcript: rawTranscript,
        context: resolvedContext,
        contextOptions: effectiveTextTransformContextOptions
      )
      .map(CloudTextMessage.init)
    return CloudTextTransformRequest(
      messages: messages,
      model: textTransformModelID
    )
  }
}

extension DictationMode {
  private enum CodingKeys: String, CodingKey {
    case audioModelID
    case customTextTransformInstructions
    case diarizationEnabled
    case iconSystemName
    case id
    case includesSystemAudio
    case languageCode
    case name
    case nameIsCustomized
    case playbackPolicy
    case realtimeEnabled
    case textTransformContextOptions
    case textTransformModelID
    case textTransformPreset
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    nameIsCustomized = try container.decodeIfPresent(Bool.self, forKey: .nameIsCustomized) ?? false
    iconSystemName = try container.decodeIfPresent(String.self, forKey: .iconSystemName)
    audioModelID = try container.decode(String.self, forKey: .audioModelID)
    languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
    realtimeEnabled = try container.decode(Bool.self, forKey: .realtimeEnabled)
    diarizationEnabled = try container.decode(Bool.self, forKey: .diarizationEnabled)
    includesSystemAudio = try container.decodeIfPresent(Bool.self, forKey: .includesSystemAudio) ?? false
    playbackPolicy =
      try container.decodeIfPresent(PlaybackPolicy.self, forKey: .playbackPolicy) ?? .keepPlaying
    textTransformPreset = try container.decode(ModeTextTransformPreset.self, forKey: .textTransformPreset)
    textTransformModelID = try container.decode(String.self, forKey: .textTransformModelID)
    customTextTransformInstructions =
      try container.decodeIfPresent(String.self, forKey: .customTextTransformInstructions)
      ?? TextTransformPreset.defaultCustomInstructions
    textTransformContextOptions =
      try container.decodeIfPresent(DictationContextOptions.self, forKey: .textTransformContextOptions)
      ?? Self.defaultTextTransformContextOptions
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(nameIsCustomized, forKey: .nameIsCustomized)
    try container.encodeIfPresent(iconSystemName, forKey: .iconSystemName)
    try container.encode(audioModelID, forKey: .audioModelID)
    try container.encodeIfPresent(languageCode, forKey: .languageCode)
    try container.encode(realtimeEnabled, forKey: .realtimeEnabled)
    try container.encode(diarizationEnabled, forKey: .diarizationEnabled)
    try container.encode(includesSystemAudio, forKey: .includesSystemAudio)
    try container.encode(playbackPolicy, forKey: .playbackPolicy)
    try container.encode(textTransformPreset, forKey: .textTransformPreset)
    try container.encode(textTransformModelID, forKey: .textTransformModelID)
    try container.encode(customTextTransformInstructions, forKey: .customTextTransformInstructions)
    try container.encode(textTransformContextOptions, forKey: .textTransformContextOptions)
  }
}
