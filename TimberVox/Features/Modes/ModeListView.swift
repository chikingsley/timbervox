import SwiftUI

struct ModeListView: View {
  let modes: [DictationMode]
  let activeModeID: String
  @Binding var selectedModeID: String?
  let onAdd: () -> Void

  var body: some View {
    List(selection: $selectedModeID) {
      ForEach(modes) { mode in
        Label {
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(mode.name)
              if mode.id == activeModeID {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
                  .accessibilityLabel("Active mode")
              }
            }
            Text(mode.textTransformPreset.label)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: mode.resolvedIconSystemName)
        }
        .tag(mode.id)
      }
    }
    .toolbar {
      ToolbarItem {
        Button("New Mode", systemImage: "plus", action: onAdd)
      }
    }
  }
}
