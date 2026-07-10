import SwiftUI

struct ModeContextPicker: View {
  @Binding var includeApplication: Bool
  @Binding var includeSelection: Bool
  @Binding var includeClipboard: Bool
  @Binding var includeScreen: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Context")
        .font(.headline)

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 18) {
          applicationToggle
          selectionToggle
          clipboardToggle
          screenToggle
        }

        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
          GridRow {
            applicationToggle
            selectionToggle
          }
          GridRow {
            clipboardToggle
            screenToggle
          }
        }
      }

      Text("Application includes the active app, window, and focused field.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var applicationToggle: some View {
    Toggle("Application", isOn: $includeApplication)
      .toggleStyle(.checkbox)
  }

  private var selectionToggle: some View {
    Toggle("Selection", isOn: $includeSelection)
      .toggleStyle(.checkbox)
  }

  private var clipboardToggle: some View {
    Toggle("Clipboard", isOn: $includeClipboard)
      .toggleStyle(.checkbox)
  }

  private var screenToggle: some View {
    Toggle("Screen text", isOn: $includeScreen)
      .toggleStyle(.checkbox)
  }
}
