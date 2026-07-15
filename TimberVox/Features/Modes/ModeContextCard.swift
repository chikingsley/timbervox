import SwiftUI

struct ModeContextCard: View {
  @Binding var includeApplication: Bool
  @Binding var includeSelection: Bool
  @Binding var includeClipboard: Bool
  @Binding var includeScreen: Bool

  var body: some View {
    SCCard(size: .sm) {
      SCCardHeader {
        SCCardTitle("Context")
        SCCardDescription("Choose which current-app information the custom prompt may use.")
      }

      SCCardContent {
        SCFieldGroup(spacing: AppSpacing.lg) {
          ModeSwitchField(
            title: "Application",
            description: "Include the active app name and window details.",
            isOn: $includeApplication
          )
          ModeSwitchField(
            title: "Selection",
            description: "Include text currently selected in the active app.",
            isOn: $includeSelection
          )
          ModeSwitchField(
            title: "Clipboard",
            description: "Include the current clipboard text.",
            isOn: $includeClipboard
          )
          ModeSwitchField(
            title: "Screen",
            description: "Include visible text captured from the active screen.",
            isOn: $includeScreen
          )
        }
      }
    }
  }
}
