import SwiftUI

/// A quiet section-level action that gains a compact ghost-button surface on hover.
struct HomeSectionLink: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
    }
    .buttonStyle(.sc(.ghost, size: .xs))
  }
}
