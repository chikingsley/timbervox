import SwiftUI

struct AppPageHeader<Trailing: View>: View {
  let title: String
  private let trailing: Trailing
  @Environment(\.theme) private var theme

  init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: AppSpacing.md) {
      SCSidebarTrigger()

      Text(title)
        .font(.system(size: 14, weight: .semibold))

      Spacer(minLength: AppSpacing.md)
      trailing
    }
    .padding(.leading, AppSpacing.sm)
    .padding(.trailing, AppSpacing.lg)
    .frame(height: AppLayout.headerHeight)
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .overlay(alignment: .bottom) {
      SCSeparator().opacity(0.7)
    }
  }
}

extension AppPageHeader where Trailing == EmptyView {
  init(title: String) {
    self.init(title) { EmptyView() }
  }
}

struct AppSearchHeader<Leading: View>: View {
  let placeholder: String
  @Binding var query: String
  private let leading: Leading
  @Environment(\.theme) private var theme

  init(
    placeholder: String,
    query: Binding<String>,
    @ViewBuilder leading: () -> Leading
  ) {
    self.placeholder = placeholder
    _query = query
    self.leading = leading()
  }

  var body: some View {
    HStack(spacing: AppSpacing.md) {
      leading

      SCInput(placeholder, text: $query, icon: "magnifyingglass", size: .sm) {
        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
          }
          .buttonStyle(.sc(.ghost, size: .iconXS))
          .accessibilityLabel("Clear search")
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.leading, AppSpacing.sm)
    .padding(.trailing, AppSpacing.lg)
    .frame(height: AppLayout.headerHeight)
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .overlay(alignment: .bottom) {
      SCSeparator().opacity(0.7)
    }
  }
}

extension AppSearchHeader where Leading == SCSidebarTrigger {
  init(placeholder: String, query: Binding<String>) {
    self.init(placeholder: placeholder, query: query) {
      SCSidebarTrigger()
    }
  }
}
