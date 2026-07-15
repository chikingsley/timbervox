import SwiftUI

struct ModeComboboxTrigger<Leading: View, Trailing: View>: View {
  let title: String
  let isExpanded: Bool
  private let leading: Leading
  private let trailing: Trailing

  @Environment(\.theme) private var theme

  init(
    title: String,
    isExpanded: Bool,
    @ViewBuilder leading: () -> Leading,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.isExpanded = isExpanded
    self.leading = leading()
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: AppSpacing.sm) {
      leading
      Text(title)
        .font(.subheadline)
        .lineLimit(1)
      Spacer(minLength: AppSpacing.sm)
      trailing
      Image(systemName: "chevron.up.chevron.down")
        .font(.caption)
        .foregroundStyle(theme.mutedForeground)
        .rotationEffect(isExpanded ? .degrees(180) : .zero)
    }
    .padding(.horizontal, 10)
    .frame(height: ModeLayout.controlHeight)
    .frame(maxWidth: .infinity)
    .background(controlSurface, in: shape)
    .overlay(shape.strokeBorder(isExpanded ? theme.ring : controlEdge))
    .overlay(alignment: .top) {
      Capsule()
        .fill(.white.opacity(0.10))
        .frame(height: 1)
        .padding(.horizontal, 5)
        .padding(.top, 1)
    }
    .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
    .contentShape(shape)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
  }

  private var controlSurface: Color {
    .adaptive(
      light: .white,
      dark: Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255)
    )
  }

  private var controlEdge: Color {
    .adaptive(
      light: Color(red: 210 / 255, green: 210 / 255, blue: 210 / 255),
      dark: Color(red: 78 / 255, green: 78 / 255, blue: 78 / 255)
    )
  }
}

extension ModeComboboxTrigger where Trailing == EmptyView {
  init(
    title: String,
    isExpanded: Bool,
    @ViewBuilder leading: () -> Leading
  ) {
    self.init(title: title, isExpanded: isExpanded, leading: leading) {
      EmptyView()
    }
  }
}
