// ============================================================
// Drawer.swift — swiftcn-ui
// Depends on: Theme/ · Button.swift
// ============================================================
import SwiftUI

// MARK: - Configuration

/// The physical edge and dismissal direction of a drawer.
public enum SCDrawerSwipeDirection: String, CaseIterable, Equatable, Hashable, Sendable {
  case up
  case right
  case down
  case left

  var isVertical: Bool {
    self == .up || self == .down
  }
}

/// How an open drawer interacts with the content behind it.
public enum SCDrawerModalBehavior: CaseIterable, Equatable, Hashable, Sendable {
  /// Shows a backdrop and makes the underlying content inert.
  case modal
  /// Leaves underlying pointer and accessibility interaction available.
  case nonModal
  /// Omits the backdrop but keeps accessibility focus in the drawer.
  case trapFocus
}

/// A vertical drawer height, expressed as a viewport fraction or native points.
public enum SCDrawerSnapPoint: Equatable, Hashable, Sendable {
  case fraction(CGFloat)
  case points(CGFloat)

  public static let full: Self = .fraction(1)

  internal func resolved(in viewport: CGFloat, maximum: CGFloat) -> CGFloat {
    let value: CGFloat
    switch self {
    case .fraction(let fraction):
      value = viewport * min(max(fraction, 0), 1)
    case .points(let points):
      value = max(points, 0)
    }
    return min(max(value, 80), maximum)
  }
}

// MARK: - Presentation environment

struct SCDrawerPresentation {
  var isPresented: Binding<Bool> = .constant(false)
  var swipeDirection: SCDrawerSwipeDirection = .down
  var modalBehavior: SCDrawerModalBehavior = .modal
  var showSwipeHandle = false
  var disablePointerDismissal = false

  func present() {
    isPresented.wrappedValue = true
  }

  func dismiss() {
    isPresented.wrappedValue = false
  }
}

private struct SCDrawerPresentationKey: EnvironmentKey {
  static let defaultValue = SCDrawerPresentation()
}

extension EnvironmentValues {
  internal var scDrawerPresentation: SCDrawerPresentation {
    get { self[SCDrawerPresentationKey.self] }
    set { self[SCDrawerPresentationKey.self] = newValue }
  }

  /// Dismisses the nearest enclosing swiftcn drawer.
  public var scDismissDrawer: () -> Void {
    scDrawerPresentation.dismiss
  }
}

// MARK: - Root

/// A controlled or internally managed drawer composed from a trigger, overlay,
/// and content. All positions, drag behavior, and snap points use one engine.
public struct SCDrawer<Trigger: View, DrawerContent: View, Overlay: View>: View {
  private let externalIsPresented: Binding<Bool>?
  private let defaultPresented: Bool
  private let modalBehavior: SCDrawerModalBehavior
  private let showSwipeHandle: Bool
  private let snapPoints: [SCDrawerSnapPoint]
  private let externalSnapPoint: Binding<SCDrawerSnapPoint?>?
  private let defaultSnapPoint: SCDrawerSnapPoint?
  private let swipeDirection: SCDrawerSwipeDirection
  private let swipeEnabled: Bool
  private let disablePointerDismissal: Bool
  private let dismissOnEscape: Bool
  private let panelSize: CGFloat?
  private let maximumPanelSize: CGFloat?
  private let onOpenChange: ((Bool) -> Void)?
  private let onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)?
  private let trigger: Trigger
  private let drawerContent: DrawerContent
  private let overlay: Overlay

  public init(
    isPresented: Binding<Bool>,
    modalBehavior: SCDrawerModalBehavior = .modal,
    showSwipeHandle: Bool = false,
    snapPoints: [SCDrawerSnapPoint] = [],
    snapPoint: Binding<SCDrawerSnapPoint?>? = nil,
    defaultSnapPoint: SCDrawerSnapPoint? = nil,
    swipeDirection: SCDrawerSwipeDirection = .down,
    swipeEnabled: Bool = true,
    disablePointerDismissal: Bool = false,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder overlay: () -> Overlay,
    @ViewBuilder content: () -> DrawerContent
  ) {
    self.externalIsPresented = isPresented
    self.defaultPresented = isPresented.wrappedValue
    self.modalBehavior = modalBehavior
    self.showSwipeHandle = showSwipeHandle
    self.snapPoints = Self.normalized(snapPoints)
    self.externalSnapPoint = snapPoint
    self.defaultSnapPoint = defaultSnapPoint
    self.swipeDirection = swipeDirection
    self.swipeEnabled = swipeEnabled
    self.disablePointerDismissal = disablePointerDismissal
    self.dismissOnEscape = dismissOnEscape
    self.panelSize = panelSize.map { max($0, 80) }
    self.maximumPanelSize = maximumPanelSize.map { max($0, 80) }
    self.onOpenChange = onOpenChange
    self.onSnapPointChange = onSnapPointChange
    self.trigger = trigger()
    self.overlay = overlay()
    self.drawerContent = content()
  }

  public init(
    defaultPresented: Bool = false,
    modalBehavior: SCDrawerModalBehavior = .modal,
    showSwipeHandle: Bool = false,
    snapPoints: [SCDrawerSnapPoint] = [],
    defaultSnapPoint: SCDrawerSnapPoint? = nil,
    swipeDirection: SCDrawerSwipeDirection = .down,
    swipeEnabled: Bool = true,
    disablePointerDismissal: Bool = false,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder overlay: () -> Overlay,
    @ViewBuilder content: () -> DrawerContent
  ) {
    self.externalIsPresented = nil
    self.defaultPresented = defaultPresented
    self.modalBehavior = modalBehavior
    self.showSwipeHandle = showSwipeHandle
    self.snapPoints = Self.normalized(snapPoints)
    self.externalSnapPoint = nil
    self.defaultSnapPoint = defaultSnapPoint
    self.swipeDirection = swipeDirection
    self.swipeEnabled = swipeEnabled
    self.disablePointerDismissal = disablePointerDismissal
    self.dismissOnEscape = dismissOnEscape
    self.panelSize = panelSize.map { max($0, 80) }
    self.maximumPanelSize = maximumPanelSize.map { max($0, 80) }
    self.onOpenChange = onOpenChange
    self.onSnapPointChange = onSnapPointChange
    self.trigger = trigger()
    self.overlay = overlay()
    self.drawerContent = content()
  }

  public var body: some View {
    SCDrawerStateContainer(
      externalIsPresented: externalIsPresented,
      defaultPresented: defaultPresented,
      modalBehavior: modalBehavior,
      showSwipeHandle: showSwipeHandle,
      snapPoints: snapPoints,
      externalSnapPoint: externalSnapPoint,
      defaultSnapPoint: defaultSnapPoint,
      swipeDirection: swipeDirection,
      swipeEnabled: swipeEnabled,
      disablePointerDismissal: disablePointerDismissal,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      onOpenChange: onOpenChange,
      onSnapPointChange: onSnapPointChange,
      presenter: trigger,
      overlay: overlay,
      drawer: drawerContent
    )
  }

  internal static func normalized(_ points: [SCDrawerSnapPoint]) -> [SCDrawerSnapPoint] {
    var seen = Set<SCDrawerSnapPoint>()
    return points.filter { seen.insert($0).inserted }
  }
}

extension SCDrawer where Overlay == SCDrawerOverlay {
  public init(
    isPresented: Binding<Bool>,
    modalBehavior: SCDrawerModalBehavior = .modal,
    showSwipeHandle: Bool = false,
    snapPoints: [SCDrawerSnapPoint] = [],
    snapPoint: Binding<SCDrawerSnapPoint?>? = nil,
    defaultSnapPoint: SCDrawerSnapPoint? = nil,
    swipeDirection: SCDrawerSwipeDirection = .down,
    swipeEnabled: Bool = true,
    disablePointerDismissal: Bool = false,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> DrawerContent
  ) {
    self.init(
      isPresented: isPresented,
      modalBehavior: modalBehavior,
      showSwipeHandle: showSwipeHandle,
      snapPoints: snapPoints,
      snapPoint: snapPoint,
      defaultSnapPoint: defaultSnapPoint,
      swipeDirection: swipeDirection,
      swipeEnabled: swipeEnabled,
      disablePointerDismissal: disablePointerDismissal,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      onOpenChange: onOpenChange,
      onSnapPointChange: onSnapPointChange,
      trigger: trigger,
      overlay: { SCDrawerOverlay() },
      content: content
    )
  }

  public init(
    defaultPresented: Bool = false,
    modalBehavior: SCDrawerModalBehavior = .modal,
    showSwipeHandle: Bool = false,
    snapPoints: [SCDrawerSnapPoint] = [],
    defaultSnapPoint: SCDrawerSnapPoint? = nil,
    swipeDirection: SCDrawerSwipeDirection = .down,
    swipeEnabled: Bool = true,
    disablePointerDismissal: Bool = false,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> DrawerContent
  ) {
    self.init(
      defaultPresented: defaultPresented,
      modalBehavior: modalBehavior,
      showSwipeHandle: showSwipeHandle,
      snapPoints: snapPoints,
      defaultSnapPoint: defaultSnapPoint,
      swipeDirection: swipeDirection,
      swipeEnabled: swipeEnabled,
      disablePointerDismissal: disablePointerDismissal,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      onOpenChange: onOpenChange,
      onSnapPointChange: onSnapPointChange,
      trigger: trigger,
      overlay: { SCDrawerOverlay() },
      content: content
    )
  }
}

// MARK: - Modifier convenience

extension View {
  /// Presents a drawer over this container using the same state and gesture
  /// engine as `SCDrawer`.
  public func scDrawer<DrawerContent: View>(
    isPresented: Binding<Bool>,
    modalBehavior: SCDrawerModalBehavior = .modal,
    showSwipeHandle: Bool = false,
    snapPoints: [SCDrawerSnapPoint] = [],
    snapPoint: Binding<SCDrawerSnapPoint?>? = nil,
    defaultSnapPoint: SCDrawerSnapPoint? = nil,
    swipeDirection: SCDrawerSwipeDirection = .down,
    swipeEnabled: Bool = true,
    disablePointerDismissal: Bool = false,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    onSnapPointChange: ((SCDrawerSnapPoint?) -> Void)? = nil,
    @ViewBuilder content: @escaping () -> DrawerContent
  ) -> some View {
    SCDrawerStateContainer(
      externalIsPresented: isPresented,
      defaultPresented: isPresented.wrappedValue,
      modalBehavior: modalBehavior,
      showSwipeHandle: showSwipeHandle,
      snapPoints: SCDrawer<EmptyView, EmptyView, EmptyView>.normalized(snapPoints),
      externalSnapPoint: snapPoint,
      defaultSnapPoint: defaultSnapPoint,
      swipeDirection: swipeDirection,
      swipeEnabled: swipeEnabled,
      disablePointerDismissal: disablePointerDismissal,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize.map { max($0, 80) },
      maximumPanelSize: maximumPanelSize.map { max($0, 80) },
      onOpenChange: onOpenChange,
      onSnapPointChange: onSnapPointChange,
      presenter: self,
      overlay: SCDrawerOverlay(),
      drawer: content()
    )
  }
}
