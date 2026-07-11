import Foundation

enum DictionarySegment: String, CaseIterable, Identifiable {
  case replacements, removals, vocabulary

  var id: String { rawValue }

  var title: String {
    switch self {
    case .replacements: "Replacements"
    case .removals: "Removals"
    case .vocabulary: "Vocabulary"
    }
  }
}

enum DictionaryRuleSource {
  case manual
  case learned(Int)

  var badge: String {
    switch self {
    case .manual: "manual"
    case .learned(let count): "learned ×\(count)"
    }
  }
}

struct DictionaryReplacement: Identifiable {
  let id = UUID()
  var match: String
  var replacement: String
  var source: DictionaryRuleSource
  var isEnabled = true

  static let mock: [DictionaryReplacement] = [
    DictionaryReplacement(match: "deep gram", replacement: "Deepgram", source: .learned(4)),
    DictionaryReplacement(match: "para keet", replacement: "Parakeet", source: .learned(7)),
    DictionaryReplacement(match: "cloud flare", replacement: "Cloudflare", source: .manual),
    DictionaryReplacement(match: "fluid audio", replacement: "FluidAudio", source: .manual),
    DictionaryReplacement(match: "ark voice", replacement: "TimberVox", source: .learned(2), isEnabled: false),
  ]
}

struct DictionaryRemoval: Identifiable {
  let id = UUID()
  var pattern: String
  var note: String
  var isEnabled = true

  static let mock: [DictionaryRemoval] = [
    DictionaryRemoval(pattern: "uh+", note: "filler"),
    DictionaryRemoval(pattern: "um+", note: "filler"),
    DictionaryRemoval(pattern: "you know", note: "hedge phrase"),
    DictionaryRemoval(pattern: "like", note: "hedge word", isEnabled: false),
    DictionaryRemoval(pattern: "ok so", note: "opener"),
  ]
}

struct DictionaryVocabTerm: Identifiable {
  let id = UUID()
  var text: String

  static let mock: [DictionaryVocabTerm] = [
    "Parakeet", "FluidAudio", "Cloudflare", "TCA", "Deepgram",
    "SwiftUI", "TimberVox", "Superwhisper", "xcstrings", "CoreML",
  ].map { DictionaryVocabTerm(text: $0) }
}
