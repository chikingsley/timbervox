import SwiftUI

struct HistoryRerunMenu: View {
  let models: [TranscriptionModelSpec]
  let isRerunning: Bool
  let audioAvailable: Bool
  let onSelect: (TranscriptionRouteSpec) -> Void
  @Environment(\.theme) private var theme

  var body: some View {
    Menu {
      if models.isEmpty {
        Button("No batch models") {}
          .disabled(true)
      } else {
        ForEach(models) { model in
          if let route = model.batchRoute {
            Button(model.menuLabel) {
              onSelect(route)
            }
          }
        }
      }
    } label: {
      Image(systemName: "arrow.clockwise")
        .font(.system(size: 11, weight: .medium))
        .frame(width: 26, height: 26)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .disabled(!audioAvailable || isRerunning)
    .foregroundStyle(theme.mutedForeground)
    .help(audioAvailable ? "Re-transcribe recording" : "The recording file is unavailable")
    .accessibilityLabel("Re-transcribe recording")
  }
}
