import SwiftUI

struct Card<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .background(
        RoundedRectangle(cornerRadius: Theme.cardRadius)
          .fill(Theme.cardSurface)
          .shadow(color: Theme.cardShadow, radius: Theme.cardShadowRadius, y: Theme.cardShadowY)
      )
  }
}
