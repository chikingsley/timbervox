import SwiftUI

struct HomeRecentActivityCard: View {
  let records: [TranscriptRecord]
  let errorMessage: String?
  let onViewHistory: () -> Void
  let onSelectRecord: (Int64?) -> Void

  var body: some View {
    SCCard(size: .sm) {
      VStack(alignment: .leading, spacing: AppSpacing.sm) {
        SCCardHeader {
          SCCardTitle("Today")
          SCCardAction {
            HomeSectionLink(title: "View history", action: onViewHistory)
              .accessibilityIdentifier("home.section.view-history")
          }
        }

        SCCardContent {
          content
        }
      }
    }
  }

  @ViewBuilder private var content: some View {
    if let errorMessage {
      SCAlert(
        icon: "exclamationmark.triangle",
        title: "History unavailable",
        description: errorMessage,
        variant: .destructive
      )
    } else if records.isEmpty {
      SCEmpty(
        "No dictations yet",
        systemImage: "waveform",
        description: "Press ⌥Space and your first result will appear here."
      )
      .frame(minHeight: 120)
    } else {
      VStack(spacing: AppSpacing.xs) {
        ForEach(Array(records.prefix(5).enumerated()), id: \.offset) { _, record in
          HomeActivityRow(item: record) {
            onSelectRecord(record.id)
          }
        }
      }
    }
  }
}
