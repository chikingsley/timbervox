import SwiftUI

let popoverSurface = Theme.popoverSurface

struct PopoverCard<Content: View>: View {
  var width: CGFloat
  var padding = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(padding)
      .frame(width: width, alignment: .leading)
      .background(Theme.tooltipSurface, in: RoundedRectangle(cornerRadius: 9))
      .overlay(
        RoundedRectangle(cornerRadius: 9)
          .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
      )
  }
}

extension View {
  func popoverPanelSurface(cornerRadius: CGFloat = 9) -> some View {
    self
      .background(popoverSurface, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
      )
  }
}
