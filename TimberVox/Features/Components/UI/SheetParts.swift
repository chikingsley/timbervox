// ============================================================
// SheetParts.swift — swiftcn-ui
// Supplemental source for: sheet
// ============================================================
import SwiftUI

// MARK: - Header, footer, title, and description

public struct SCSheetHeader<Content: View>: View {
  private let alignment: HorizontalAlignment
  private let content: Content

  public init(
    alignment: HorizontalAlignment = .leading,
    @ViewBuilder content: () -> Content
  ) {
    self.alignment = alignment
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: alignment, spacing: 6) {
      content
    }
    .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
  }
}

/// A bottom action region with arbitrary content.
public struct SCSheetFooter<Content: View>: View {
  private let alignment: HorizontalAlignment
  private let content: Content

  public init(
    alignment: HorizontalAlignment = .leading,
    @ViewBuilder content: () -> Content
  ) {
    self.alignment = alignment
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: alignment, spacing: 8) {
      content
    }
    .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
  }
}

public struct SCSheetTitle<Content: View>: View {
  @Environment(\.theme) private var theme
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.headline)
      .foregroundStyle(theme.foreground)
      .accessibilityAddTraits(.isHeader)
  }
}

extension SCSheetTitle where Content == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }
}

public struct SCSheetDescription<Content: View>: View {
  @Environment(\.theme) private var theme
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.subheadline)
      .foregroundStyle(theme.mutedForeground)
  }
}

extension SCSheetDescription where Content == Text {
  public init(_ description: String) {
    self.init { Text(description) }
  }
}
