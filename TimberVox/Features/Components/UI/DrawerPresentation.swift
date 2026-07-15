import SwiftUI

struct SCDrawerStateContainer<Presenter: View, Overlay: View, DrawerContent: View>: View {
  @State private var internalIsPresented: Bool
  @State private var internalSnapPoint: SCDrawerSnapPoint?

  let externalIsPresented: Binding<Bool>?
  let modalBehavior: SCDrawerModalBehavior
  let showSwipeHandle: Bool
  let snapPoints: [SCDrawerSnapPoint]
  let externalSnapPoint: Binding<SCDrawerSnapPoint?>?
  let swipeDirection: SCDrawerSwipeDirection
  let swipeEnabled: Bool
  let disablePointerDismissal: Bool
  let dismissOnEscape: Bool
  let panelSize: CGFloat?
  let maximumPanelSize: CGFloat?
  let onOpenChange: ((Bool) -> Void)?
  let onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)?
  let presenter: Presenter
  let overlay: Overlay
  let drawer: DrawerContent

  init(
    externalIsPresented: Binding<Bool>?,
    defaultPresented: Bool,
    modalBehavior: SCDrawerModalBehavior,
    showSwipeHandle: Bool,
    snapPoints: [SCDrawerSnapPoint],
    externalSnapPoint: Binding<SCDrawerSnapPoint?>?,
    defaultSnapPoint: SCDrawerSnapPoint?,
    swipeDirection: SCDrawerSwipeDirection,
    swipeEnabled: Bool,
    disablePointerDismissal: Bool,
    dismissOnEscape: Bool,
    panelSize: CGFloat?,
    maximumPanelSize: CGFloat?,
    onOpenChange: ((Bool) -> Void)?,
    onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)?,
    presenter: Presenter,
    overlay: Overlay,
    drawer: DrawerContent
  ) {
    self.externalIsPresented = externalIsPresented
    self._internalIsPresented = State(initialValue: defaultPresented)
    self.modalBehavior = modalBehavior
    self.showSwipeHandle = showSwipeHandle
    self.snapPoints = snapPoints
    self.externalSnapPoint = externalSnapPoint
    let initialSnapPoint =
      externalSnapPoint?.wrappedValue
      ?? defaultSnapPoint
      ?? snapPoints.first
    self._internalSnapPoint = State(initialValue: initialSnapPoint)
    self.swipeDirection = swipeDirection
    self.swipeEnabled = swipeEnabled
    self.disablePointerDismissal = disablePointerDismissal
    self.dismissOnEscape = dismissOnEscape
    self.panelSize = panelSize
    self.maximumPanelSize = maximumPanelSize
    self.onOpenChange = onOpenChange
    self.onSnapPointChange = onSnapPointChange
    self.presenter = presenter
    self.overlay = overlay
    self.drawer = drawer
  }

  var body: some View {
    SCDrawerPresentationLayer(
      isPresented: presented,
      modalBehavior: modalBehavior,
      showSwipeHandle: showSwipeHandle,
      snapPoints: swipeDirection.isVertical ? snapPoints : [],
      snapPoint: activeSnapPoint,
      swipeDirection: swipeDirection,
      swipeEnabled: swipeEnabled,
      disablePointerDismissal: disablePointerDismissal,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      presenter: presenter,
      overlay: overlay,
      drawer: drawer
    )
  }

  private var presented: Binding<Bool> {
    Binding {
      externalIsPresented?.wrappedValue ?? internalIsPresented
    } set: { newValue in
      let oldValue = externalIsPresented?.wrappedValue ?? internalIsPresented
      guard oldValue != newValue else { return }
      if let externalIsPresented {
        externalIsPresented.wrappedValue = newValue
      } else {
        internalIsPresented = newValue
      }
      onOpenChange?(newValue)
    }
  }

  private var activeSnapPoint: Binding<SCDrawerSnapPoint?> {
    Binding {
      let proposed = externalSnapPoint?.wrappedValue ?? internalSnapPoint
      if let proposed, snapPoints.contains(proposed) { return proposed }
      return snapPoints.first
    } set: { newValue in
      guard newValue != (externalSnapPoint?.wrappedValue ?? internalSnapPoint) else {
        return
      }
      if let externalSnapPoint {
        externalSnapPoint.wrappedValue = newValue
      } else {
        internalSnapPoint = newValue
      }
      onSnapPointChange?(newValue)
    }
  }
}

struct SCDrawerPresentationLayer<Presenter: View, Overlay: View, DrawerContent: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.layoutDirection) private var layoutDirection
  @Namespace private var drawerFocusScope

  @State private var dragProgress: CGFloat = 0
  @State private var isDragging = false

  let isPresented: Binding<Bool>
  let modalBehavior: SCDrawerModalBehavior
  let showSwipeHandle: Bool
  let snapPoints: [SCDrawerSnapPoint]
  let snapPoint: Binding<SCDrawerSnapPoint?>
  let swipeDirection: SCDrawerSwipeDirection
  let swipeEnabled: Bool
  let disablePointerDismissal: Bool
  let dismissOnEscape: Bool
  let panelSize: CGFloat?
  let maximumPanelSize: CGFloat?
  let presenter: Presenter
  let overlay: Overlay
  let drawer: DrawerContent

  var body: some View {
    ZStack {
      backgroundPresenter

      if isPresented.wrappedValue {
        GeometryReader { proxy in
          ZStack(alignment: alignment) {
            if modalBehavior == .modal {
              overlay
                .opacity(overlayOpacity(in: proxy.size))
                .transition(.opacity)
            }

            focusScopedDrawer(in: proxy.size)
              .offset(drawerOffset)
              .simultaneousGesture(dragGesture(in: proxy.size))
              .transition(.move(edge: transitionEdge))
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .environment(
      \.scDrawerPresentation,
      SCDrawerPresentation(
        isPresented: isPresented,
        swipeDirection: swipeDirection,
        modalBehavior: modalBehavior,
        showSwipeHandle: showSwipeHandle,
        disablePointerDismissal: disablePointerDismissal
      )
    )
    .onKeyPress(.escape) {
      guard isPresented.wrappedValue, dismissOnEscape else { return .ignored }
      isPresented.wrappedValue = false
      return .handled
    }
    #if os(macOS)
      .onExitCommand {
        if isPresented.wrappedValue, dismissOnEscape {
          isPresented.wrappedValue = false
        }
      }
    #endif
    .onChange(of: isPresented.wrappedValue) { _, presented in
      if presented {
        dragProgress = 0
        if !snapPoints.isEmpty, snapPoint.wrappedValue == nil {
          snapPoint.wrappedValue = snapPoints.first
        }
      }
    }
    .animation(
      reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88),
      value: isPresented.wrappedValue
    )
  }

  @ViewBuilder
  private var backgroundPresenter: some View {
    switch modalBehavior {
    case .modal:
      presenter
        .disabled(isPresented.wrappedValue)
        .accessibilityHidden(isPresented.wrappedValue)
    case .trapFocus:
      presenter
        .accessibilityHidden(isPresented.wrappedValue)
    case .nonModal:
      if isPresented.wrappedValue, !disablePointerDismissal {
        presenter.simultaneousGesture(
          TapGesture().onEnded { isPresented.wrappedValue = false }
        )
      } else {
        presenter
      }
    }
  }

  @ViewBuilder
  private func sizedDrawer(in viewport: CGSize) -> some View {
    let maximum = maximumDimension(in: viewport)
    let snapSize = currentSnapSize(in: viewport)

    if swipeDirection.isVertical {
      drawer
        .frame(height: snapSize ?? panelSize)
        .frame(maxWidth: .infinity, maxHeight: maximum, alignment: panelAlignment)
        .accessibilityAddTraits(modalBehavior == .nonModal ? [] : .isModal)
    } else {
      drawer
        .frame(width: panelSize ?? min(viewport.width * 0.75, 384))
        .frame(maxWidth: maximum, maxHeight: .infinity, alignment: panelAlignment)
        .accessibilityAddTraits(modalBehavior == .nonModal ? [] : .isModal)
    }
  }

  @ViewBuilder
  private func focusScopedDrawer(in viewport: CGSize) -> some View {
    #if os(macOS)
      sizedDrawer(in: viewport)
        .focusScope(drawerFocusScope)
    #else
      sizedDrawer(in: viewport)
    #endif
  }

  private var alignment: Alignment {
    switch swipeDirection {
    case .down: .bottom
    case .up: .top
    case .left: physicalLeftAlignment
    case .right: physicalRightAlignment
    }
  }

  private var panelAlignment: Alignment {
    alignment
  }

  private var physicalLeftAlignment: Alignment {
    layoutDirection == .leftToRight ? .leading : .trailing
  }

  private var physicalRightAlignment: Alignment {
    layoutDirection == .leftToRight ? .trailing : .leading
  }

  private var transitionEdge: Edge {
    switch swipeDirection {
    case .down: .bottom
    case .up: .top
    case .left: layoutDirection == .leftToRight ? .leading : .trailing
    case .right: layoutDirection == .leftToRight ? .trailing : .leading
    }
  }

  private var drawerOffset: CGSize {
    guard snapPoints.isEmpty else { return .zero }
    return switch swipeDirection {
    case .down: CGSize(width: 0, height: dragProgress)
    case .up: CGSize(width: 0, height: -dragProgress)
    case .right: CGSize(width: dragProgress, height: 0)
    case .left: CGSize(width: -dragProgress, height: 0)
    }
  }

  private func maximumDimension(in viewport: CGSize) -> CGFloat {
    let dimension = swipeDirection.isVertical ? viewport.height : viewport.width
    let defaultMaximum = swipeDirection.isVertical ? max(dimension - 96, 80) : dimension
    return min(maximumPanelSize ?? defaultMaximum, dimension)
  }

  private func resolvedSnapPoints(in viewport: CGSize) -> [(SCDrawerSnapPoint, CGFloat)] {
    let maximum = maximumDimension(in: viewport)
    return
      snapPoints
      .map { ($0, $0.resolved(in: viewport.height, maximum: maximum)) }
      .sorted { $0.1 < $1.1 }
  }

  private func currentSnapSize(in viewport: CGSize) -> CGFloat? {
    let points = resolvedSnapPoints(in: viewport)
    guard !points.isEmpty else { return nil }
    let active = snapPoint.wrappedValue ?? points[0].0
    let base = points.first { $0.0 == active }?.1 ?? points[0].1
    return min(max(base - dragProgress, 0), maximumDimension(in: viewport))
  }

  private func overlayOpacity(in viewport: CGSize) -> Double {
    let maximum = max(maximumDimension(in: viewport), 1)
    if let current = currentSnapSize(in: viewport) {
      return Double(min(max(0.5 + 0.5 * (current / maximum), 0), 1))
    }
    let progress = min(max(dragProgress / maximum, 0), 1)
    return Double(1 - progress)
  }

  private func dragGesture(in viewport: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        guard swipeEnabled, isDominant(value.translation) else { return }
        isDragging = true
        let translation = directional(value.translation)
        if snapPoints.isEmpty {
          dragProgress = translation >= 0 ? translation : translation / 10
        } else {
          dragProgress = translation
        }
      }
      .onEnded { value in
        guard isDragging else { return }
        isDragging = false
        finishDrag(value, in: viewport)
      }
  }

  private func finishDrag(_ value: DragGesture.Value, in viewport: CGSize) {
    let projected = directional(value.predictedEndTranslation)
    if snapPoints.isEmpty {
      let threshold = max(80, maximumDimension(in: viewport) * 0.22)
      if projected > threshold, !disablePointerDismissal {
        isPresented.wrappedValue = false
      }
      resetDrag()
      return
    }

    let points = resolvedSnapPoints(in: viewport)
    guard !points.isEmpty else {
      resetDrag()
      return
    }
    let current = snapPoint.wrappedValue ?? points[0].0
    let index = points.firstIndex { $0.0 == current } ?? 0
    let threshold: CGFloat = 50

    if projected > threshold {
      if index > 0 {
        snapPoint.wrappedValue = points[index - 1].0
      } else if !disablePointerDismissal {
        isPresented.wrappedValue = false
      }
    } else if projected < -threshold, index < points.count - 1 {
      snapPoint.wrappedValue = points[index + 1].0
    } else {
      let visible = currentSnapSize(in: viewport) ?? points[index].1
      snapPoint.wrappedValue =
        points.min {
          abs($0.1 - visible) < abs($1.1 - visible)
        }?.0
    }
    resetDrag()
  }

  private func resetDrag() {
    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
      dragProgress = 0
    }
  }

  private func isDominant(_ translation: CGSize) -> Bool {
    swipeDirection.isVertical
      ? abs(translation.height) >= abs(translation.width)
      : abs(translation.width) >= abs(translation.height)
  }

  private func directional(_ translation: CGSize) -> CGFloat {
    switch swipeDirection {
    case .down: translation.height
    case .up: -translation.height
    case .right: translation.width
    case .left: -translation.width
    }
  }
}
