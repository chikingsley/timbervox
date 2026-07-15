import SwiftUI

extension View {
  func appNoticeDialog(
    isPresented: Binding<Bool>,
    title: String,
    message: String,
    buttonLabel: String = "OK"
  ) -> some View {
    modifier(
      AppNoticeDialogModifier(
        isPresented: isPresented,
        title: title,
        message: message,
        buttonLabel: buttonLabel
      ))
  }
}

private struct AppNoticeDialogModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Binding var isPresented: Bool
  var title: String
  var message: String
  var buttonLabel: String

  func body(content: Content) -> some View {
    content.overlay {
      if isPresented {
        ZStack {
          SCAlertDialogOverlay()
          SCAlertDialogContent {
            SCAlertDialogHeader {
              SCAlertDialogTitle(title)
              SCAlertDialogDescription(message)
            }
            SCAlertDialogFooter {
              SCAlertDialogAction(buttonLabel) {
                isPresented = false
              }
            }
          }
          .accessibilityAddTraits(.isModal)
          .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .environment(
          \.scAlertDialogPresentation,
          SCAlertDialogPresentation(isPresented: $isPresented)
        )
      }
    }
    .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isPresented)
  }
}
