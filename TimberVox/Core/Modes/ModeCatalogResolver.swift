struct ModeModelCapabilities: Equatable, Sendable {
  var model: TranscriptionModelSpec
  var route: TranscriptionRouteSpec
  var transport: DictationExecutionPlan.Transport

  var supportsBatch: Bool { model.supportsBatch }
  var supportsRealtime: Bool { model.supportsRealtime }
  var supportsAutomaticLanguage: Bool { route.supportsAutomaticLanguage }
  var supportsDiarization: Bool { route.supportsDiarization }
  var supportedLanguages: [String] { route.supportedLanguages }
}

enum ModeCatalogResolver {
  static func capabilities(
    for mode: DictationMode,
    catalog: [TranscriptionModelSpec]
  ) -> ModeModelCapabilities? {
    guard let model = catalog.first(where: { $0.id == mode.audioModelID }) else { return nil }
    let transport: DictationExecutionPlan.Transport = mode.realtimeEnabled ? .realtime : .batch
    guard let route = route(for: transport, model: model) else { return nil }
    return ModeModelCapabilities(model: model, route: route, transport: transport)
  }

  static func normalized(
    _ mode: DictationMode,
    catalog: [TranscriptionModelSpec],
    fallbackIfModelMissing: Bool = true
  ) -> DictationMode {
    guard !catalog.isEmpty else { return mode }
    var result = mode
    var model = catalog.first { $0.id == result.audioModelID }

    if model == nil, fallbackIfModelMissing, let fallback = fallbackAudioModel(in: catalog) {
      result.audioModelID = fallback.id
      result.diarizationEnabled = false
      model = fallback
    }
    guard let model else { return result }

    if !model.supportsRealtime {
      result.realtimeEnabled = false
    } else if !model.supportsBatch {
      result.realtimeEnabled = true
    }

    guard let capabilities = capabilities(for: result, catalog: catalog) else { return result }
    result.languageCode = normalizedLanguageCode(
      result.languageCode,
      capabilities: capabilities
    )
    if !capabilities.supportsDiarization {
      result.diarizationEnabled = false
    }
    return result
  }

  static func executionPlan(
    for mode: DictationMode,
    catalog: [TranscriptionModelSpec]
  ) throws -> DictationExecutionPlan {
    let resolvedMode = mode
    guard let model = catalog.first(where: { $0.id == resolvedMode.audioModelID }) else {
      throw TranscriptionRuntimeError.configuration("Unknown audio model: \(mode.audioModelID)")
    }
    let transport: DictationExecutionPlan.Transport = resolvedMode.realtimeEnabled ? .realtime : .batch
    guard let route = route(for: transport, model: model) else {
      let routeName = transport == .realtime ? "realtime" : "batch"
      throw TranscriptionRuntimeError.configuration("\(model.displayName) does not have a \(routeName) route.")
    }
    guard !route.supportedLanguages.isEmpty else {
      throw TranscriptionRuntimeError.configuration("\(model.displayName) has no published supported languages.")
    }
    if resolvedMode.languageCode == nil, !route.supportsAutomaticLanguage {
      throw TranscriptionRuntimeError.configuration(
        "\(model.displayName) does not support automatic language selection.")
    }
    if let languageCode = resolvedMode.languageCode,
      !route.supportedLanguages.contains(languageCode)
    {
      throw TranscriptionRuntimeError.configuration(
        "\(model.displayName) does not support \(ModeLanguageLabel.name(for: languageCode))."
      )
    }
    if resolvedMode.diarizationEnabled, !route.supportsDiarization {
      throw TranscriptionRuntimeError.configuration("\(model.displayName) does not support diarization on this route.")
    }
    return DictationExecutionPlan(mode: resolvedMode, route: route, transport: transport)
  }

  static func fallbackAudioModel(in catalog: [TranscriptionModelSpec]) -> TranscriptionModelSpec? {
    catalog.first {
      $0.id == DictationModeDefaults.batchModelID && $0.supportsBatch
    }
      ?? catalog.first {
        $0.supportsBatch || $0.supportsRealtime
      }
  }

  private static func normalizedLanguageCode(
    _ languageCode: String?,
    capabilities: ModeModelCapabilities
  ) -> String? {
    if let languageCode, capabilities.supportedLanguages.contains(languageCode) {
      return languageCode
    }
    if capabilities.supportsAutomaticLanguage {
      return nil
    }
    if capabilities.supportedLanguages.contains("en") {
      return "en"
    }
    return capabilities.supportedLanguages.first
  }

  private static func route(
    for transport: DictationExecutionPlan.Transport,
    model: TranscriptionModelSpec
  ) -> TranscriptionRouteSpec? {
    switch transport {
    case .batch: model.batchRoute
    case .realtime: model.realtimeRoute
    }
  }
}
