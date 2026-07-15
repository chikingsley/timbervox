import SwiftUI

struct HomeActivityRow: View {
  let item: TranscriptRecord
  let action: () -> Void
  @Environment(\.theme) private var theme

  var body: some View {
    Button(action: action) {
      SCItem(
        variant: .default,
        leading: {
          HistorySourceApplicationIcon(record: item, size: 32)
        },
        title: {
          Text(item.text)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
        },
        description: {
          Text("\(item.sourceApplicationName ?? "TimberVox") · \(item.wordCount) words")
            .font(.system(size: 11))
            .lineLimit(1)
        },
        trailing: {
          VStack(alignment: .trailing, spacing: 2) {
            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
            Text(HomePane.formatDuration(item.durationSeconds))
              .monospacedDigit()
          }
          .font(.system(size: 10))
          .foregroundStyle(theme.mutedForeground)
        }
      )
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.sc(.ghost, size: .sm))
    .help("Open in History")
  }
}
