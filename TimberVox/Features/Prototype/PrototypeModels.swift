import Foundation

enum PrototypeDestination: String, CaseIterable, Identifiable {
  case home
  case modes
  case history
  case transcriptions
  case meetings
  case commands
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .home: "Home"
    case .modes: "Modes"
    case .history: "History"
    case .transcriptions: "Transcriptions"
    case .meetings: "Meetings"
    case .commands: "Commands"
    case .settings: "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .home: "house"
    case .modes: "slider.horizontal.3"
    case .history: "clock.arrow.circlepath"
    case .transcriptions: "doc.text"
    case .meetings: "person.2.wave.2"
    case .commands: "waveform.badge.mic"
    case .settings: "gearshape"
    }
  }
}

struct PrototypeMode: Identifiable, Hashable {
  let id: UUID
  var name: String
  var icon: String
  var transcriptionModel: String
  var language: String
  var transform: String
  var customPrompt: String
  var contextSources: Set<String>
  var activationApps: [String]
  var includesSystemAudio: Bool
  var isActive: Bool
}

extension PrototypeMode {
  static let samples: [Self] = [
    .init(
      id: UUID(), name: "Voice to Text", icon: "waveform", transcriptionModel: "Nova 3",
      language: "Automatic", transform: "None", customPrompt: "",
      contextSources: ["Application", "Selected text"],
      activationApps: [], includesSystemAudio: false, isActive: true),
    .init(
      id: UUID(), name: "Email", icon: "envelope", transcriptionModel: "Scribe v2",
      language: "English", transform: "Email", customPrompt: "",
      contextSources: ["Application", "Selected text", "Clipboard"],
      activationApps: ["Mail", "Gmail"], includesSystemAudio: false, isActive: false),
    .init(
      id: UUID(), name: "Notes", icon: "note.text", transcriptionModel: "Nova 3",
      language: "Automatic", transform: "Note", customPrompt: "",
      contextSources: ["Application", "Focused text"],
      activationApps: ["Notes", "Obsidian"], includesSystemAudio: false, isActive: false),
    .init(
      id: UUID(), name: "Meeting Follow-up", icon: "person.2", transcriptionModel: "Nova 3",
      language: "English", transform: "Custom",
      customPrompt: "Turn this dictation into a concise follow-up with decisions and clear action items.",
      contextSources: ["Application", "Clipboard"],
      activationApps: ["Zoom", "Microsoft Teams"], includesSystemAudio: true, isActive: false),
  ]
}

struct PrototypeHistoryItem: Identifiable, Hashable {
  enum Status: String {
    case delivered = "Delivered"
    case noSpeech = "No speech"
    case failed = "Failed"
  }

  let id: UUID
  let deliveredText: String
  let rawText: String?
  let createdAt: Date
  let duration: TimeInterval
  let mode: String
  let model: String
  let provider: String
  let application: String
  let status: Status
}

extension PrototypeHistoryItem {
  static let samples: [Self] = [
    .init(
      id: UUID(),
      deliveredText:
        "Could we move the design review to Thursday afternoon? I will send the revised prototype beforehand.",
      rawText: "could we move the design review to thursday afternoon i'll send the revised prototype before hand",
      createdAt: .now.addingTimeInterval(-420), duration: 12, mode: "Email", model: "Scribe v2",
      provider: "ElevenLabs", application: "Mail", status: .delivered),
    .init(
      id: UUID(),
      deliveredText: "The recording path is working. Next, verify the permission recovery flow and the history detail.",
      rawText: nil, createdAt: .now.addingTimeInterval(-3_900), duration: 9, mode: "Voice to Text",
      model: "Nova 3", provider: "Deepgram", application: "Xcode", status: .delivered),
    .init(
      id: UUID(), deliveredText: "No speech was detected.", rawText: nil,
      createdAt: .now.addingTimeInterval(-8_200), duration: 3, mode: "Voice to Text",
      model: "Nova 3", provider: "Deepgram", application: "Safari", status: .noSpeech),
    .init(
      id: UUID(), deliveredText: "The network connection ended before transcription completed.", rawText: nil,
      createdAt: .now.addingTimeInterval(-86_400), duration: 18, mode: "Notes", model: "Nova 3",
      provider: "Deepgram", application: "Notes", status: .failed),
  ]
}

struct PrototypeTranscription: Identifiable, Hashable {
  enum Status: String, CaseIterable {
    case complete = "Complete"
    case processing = "Processing"
    case queued = "Queued"
    case failed = "Failed"
  }

  let id: UUID
  var title: String
  var status: Status
  var duration: TimeInterval
  var date: Date
  var speakers: Int
  var segments: [PrototypeTranscriptSegment]
}

struct PrototypeTranscriptSegment: Identifiable, Hashable {
  let id: UUID
  var speaker: String
  var timestamp: TimeInterval
  var text: String
}

extension PrototypeTranscription {
  static let samples: [Self] = [
    .init(
      id: UUID(), title: "Product interview.m4a", status: .complete, duration: 1_842,
      date: .now.addingTimeInterval(-7_200), speakers: 2,
      segments: [
        .init(id: UUID(), speaker: "Simon", timestamp: 0, text: "What does your current dictation workflow look like?"),
        .init(
          id: UUID(), speaker: "Guest", timestamp: 5,
          text: "I switch between a plain mode and one that rewrites messages for email."),
        .init(
          id: UUID(), speaker: "Simon", timestamp: 13,
          text: "So seeing the available modes matters more than searching a large library."),
      ]),
    .init(
      id: UUID(), title: "Field notes.wav", status: .processing, duration: 734,
      date: .now.addingTimeInterval(-90_000), speakers: 1, segments: []),
    .init(
      id: UUID(), title: "Demo recording.mp3", status: .queued, duration: 288,
      date: .now.addingTimeInterval(-172_800), speakers: 1, segments: []),
  ]
}

struct PrototypeMeeting: Identifiable, Hashable {
  let id: UUID
  var title: String
  var date: Date
  var duration: TimeInterval
  var participants: [String]
  var summary: String
  var actionItems: [String]
}

extension PrototypeMeeting {
  static let samples: [Self] = [
    .init(
      id: UUID(), title: "TimberVox design review", date: .now.addingTimeInterval(-86_400),
      duration: 2_715, participants: ["Simon", "Maya", "Jon"],
      summary:
        "The team agreed to keep one system sidebar and prototype each collection with stock macOS controls before production integration.",
      actionItems: [
        "Review the connected prototype", "Choose the initial Home state", "Promote the accepted Modes layout",
      ]),
    .init(
      id: UUID(), title: "Cloud transcription planning", date: .now.addingTimeInterval(-259_200),
      duration: 3_420, participants: ["Simon", "Alex"],
      summary:
        "Reviewed provider routing, upload ownership, and the distinction between dictation and durable transcription documents.",
      actionItems: ["Verify the live upload path", "Save provider latency metadata"]),
  ]
}

struct PrototypeVoiceCommand: Identifiable, Hashable {
  let id: UUID
  var name: String
  var trigger: String
  var action: String
  var confirmation: String
  var mode: String
  var isEnabled: Bool
}

extension PrototypeVoiceCommand {
  static let samples: [Self] = [
    .init(
      id: UUID(), name: "New note", trigger: "Take a note", action: "Start standalone note", confirmation: "Sound",
      mode: "Notes", isEnabled: true),
    .init(
      id: UUID(), name: "Start meeting", trigger: "Start the meeting", action: "Open meeting setup",
      confirmation: "Ask first", mode: "Any mode", isEnabled: true),
    .init(
      id: UUID(), name: "Send follow-up", trigger: "Draft a follow-up", action: "Run Email workflow",
      confirmation: "Show result", mode: "Email", isEnabled: false),
  ]
}
