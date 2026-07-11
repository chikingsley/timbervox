struct DictationExecutionPlan: Equatable, Sendable {
  enum Transport: Equatable, Sendable {
    case batch
    case realtime
  }

  var mode: DictationMode
  var route: TranscriptionRouteSpec
  var transport: Transport
}
