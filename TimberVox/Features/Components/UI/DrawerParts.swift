// ============================================================
// DrawerParts.swift — swiftcn-ui
// Supplemental source for: drawer
// ============================================================
import SwiftUI

// MARK: - Trigger, overlay, and close

public struct SCDrawerTrigger<Label: View>: View {
  @Environment(\.scDrawerPresentation) private var presentation
  @FocusState private var isFocused: Bool
  @State private var openedFromHere = false

  private let label: Label

  public init(@ViewBuilder label: () -> Label) {
    self.label = label()
  }

  public var body: some View {
    Button {
      openedFromHere = true
      presentation.present()
    } label: {
      label
    }
    .focused($isFocused)
    .onChange(of: presentation.isPresented.wrappedValue) { wasPresented, isPresented in
      if wasPresented, !isPresented, openedFromHere {
        isFocused = true
        openedFromHere = false
      }
    }
  }
}

extension SCDrawerTrigger where Label == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }
}

public struct SCDrawerOverlay: View {
  @Environment(\.scDrawerPresentation) private var presentation
  private let opacity: Double

  public init(opacity: Double = 0.5) {
    self.opacity = min(max(opacity, 0), 1)
  }

  public var body: some View {
    Color.black.opacity(opacity)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea()
      .contentShape(Rectangle())
      .onTapGesture {
        if !presentation.disablePointerDismissal {
          presentation.dismiss()
        }
      }
      .accessibilityHidden(true)
  }
}

public struct SCDrawerClose<Label: View>: View {
  @Environment(\.scDrawerPresentation) private var presentation

  private let action: () -> Void
  private let label: Label

  public init(
    action: @escaping () -> Void = {},
    @ViewBuilder label: () -> Label
  ) {
    self.action = action
    self.label = label()
  }

  public var body: some View {
    Button {
      presentation.dismiss()
      action()
    } label: {
      label
    }
  }
}

extension SCDrawerClose where Label == Text {
  public init(_ title: String = "Close", action: @escaping () -> Void = {}) {
    self.init(action: action) { Text(title) }
  }
}

// MARK: - Content and swipe handle

public struct SCDrawerContent<Content: View>: View {
  @Environment(\.scDrawerPresentation) private var presentation
  @Environment(\.theme) private var theme
  @FocusState private var isFocused: Bool

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    arrangedContent
      .frame(maxWidth: presentation.swipeDirection.isVertical ? .infinity : nil)
      .frame(maxHeight: presentation.swipeDirection.isVertical ? nil : .infinity)
      .background {
        drawerShape.fill(theme.background)
      }
      .overlay { drawerShape.strokeBorder(theme.border) }
      .clipShape(drawerShape)
      .foregroundStyle(theme.foreground)
      .accessibilityElement(children: .contain)
      .focusable()
      .focused($isFocused)
      .onAppear { isFocused = true }
  }

  @ViewBuilder
  private var arrangedContent: some View {
    switch presentation.swipeDirection {
    case .down:
      VStack(spacing: 0) {
        automaticHandle
        content
      }
    case .up:
      VStack(spacing: 0) {
        content
        automaticHandle
      }
    case .left:
      HStack(spacing: 0) {
        VStack(spacing: 0) { content }
        automaticHandle
      }
    case .right:
      HStack(spacing: 0) {
        automaticHandle
        VStack(spacing: 0) { content }
      }
    }
  }

  @ViewBuilder
  private var automaticHandle: some View {
    if presentation.showSwipeHandle {
      SCDrawerSwipeHandle()
    }
  }

  private var drawerShape: UnevenRoundedRectangle {
    let radius = theme.radius + 6
    return switch presentation.swipeDirection {
    case .down:
      UnevenRoundedRectangle(
        topLeadingRadius: radius,
        topTrailingRadius: radius,
        style: .continuous
      )
    case .up:
      UnevenRoundedRectangle(
        bottomLeadingRadius: radius,
        bottomTrailingRadius: radius,
        style: .continuous
      )
    case .left, .right:
      UnevenRoundedRectangle(
        topLeadingRadius: radius,
        bottomLeadingRadius: radius,
        bottomTrailingRadius: radius,
        topTrailingRadius: radius,
        style: .continuous
      )
    }
  }
}

public struct SCDrawerSwipeHandle: View {
  @Environment(\.scDrawerPresentation) private var presentation
  @Environment(\.theme) private var theme

  public init() {}

  public var body: some View {
    Capsule()
      .fill(theme.mutedForeground.opacity(0.35))
      .frame(
        width: presentation.swipeDirection.isVertical ? 40 : 5,
        height: presentation.swipeDirection.isVertical ? 5 : 40
      )
      .padding(8)
      .contentShape(Rectangle())
      .accessibilityHidden(true)
  }
}

// MARK: - Header, title, description, scroll content, and footer

public struct SCDrawerHeader<Content: View>: View {
  @Environment(\.scDrawerPresentation) private var presentation
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(
      alignment: presentation.swipeDirection.isVertical ? .center : .leading,
      spacing: 6
    ) {
      content
    }
    .multilineTextAlignment(presentation.swipeDirection.isVertical ? .center : .leading)
    .frame(
      maxWidth: .infinity,
      alignment: presentation.swipeDirection.isVertical ? .center : .leading
    )
    .padding(16)
  }
}

public struct SCDrawerTitle<Content: View>: View {
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

extension SCDrawerTitle where Content == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }
}

public struct SCDrawerDescription<Content: View>: View {
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

extension SCDrawerDescription where Content == Text {
  public init(_ description: String) {
    self.init { Text(description) }
  }
}

public struct SCDrawerScrollContent<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    ScrollView {
      content
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
    .frame(maxHeight: .infinity)
  }
}

public struct SCDrawerFooter<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: 8) {
      content
    }
    .frame(maxWidth: .infinity)
    .padding(16)
  }
}
