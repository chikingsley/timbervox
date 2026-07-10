import SwiftUI

struct TranscriptionModelExperienceView: View {
  let model: TranscriptionModelSpec

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(model.runtime.label)
          .font(.caption.weight(.medium))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())

        if let quality = model.presentation.quality {
          RatingDots(label: "Quality", rating: quality)
        }
        if let response = model.presentation.response {
          RatingDots(label: "Response", rating: response)
        }
      }

      Text(model.presentation.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct RatingDots: View {
  let label: String
  let rating: ModelRating

  var body: some View {
    HStack(spacing: 3) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      ForEach(1...5, id: \.self) { score in
        Circle()
          .fill(score <= rating.score ? Color.accentColor : Color.secondary.opacity(0.25))
          .frame(width: 5, height: 5)
      }
    }
    .help("\(label) \(rating.score) of 5. \(rating.explanation)")
    .accessibilityLabel("\(label), \(rating.score) out of 5")
  }
}
