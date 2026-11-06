import AppKit
import SwiftUI

/// A separate, noninteractive window lets the label extend above the compact Dock panel.
struct DockTooltip: ViewModifier {
  let title: String
  @EnvironmentObject private var session: DockTooltipSession
  @State private var hovering = false

  func body(content: Content) -> some View {
    content
      .background { DockTooltipAnchor(title: title, hovering: hovering, session: session) }
      .onHover { hovering = $0 }
      .onDisappear { hovering = false }
  }
}

private struct DockTooltipAnchor: NSViewRepresentable {
  let title: String
  let hovering: Bool
  let session: DockTooltipSession

  func makeNSView(context: Context) -> DockTooltipAnchorView { DockTooltipAnchorView() }

  func updateNSView(_ view: DockTooltipAnchorView, context: Context) {
    view.update(title: title, hovering: hovering, session: session)
  }

  static func dismantleNSView(_ view: DockTooltipAnchorView, coordinator: ()) {
    view.detach()
  }
}

private final class DockTooltipAnchorView: NSView {
  private var title = ""
  private var hovering = false
  private weak var session: DockTooltipSession?

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    detach()
  }

  func update(title: String, hovering: Bool, session: DockTooltipSession) {
    let changed = self.title != title || self.hovering != hovering || self.session !== session
    if self.session !== session { detach() }
    self.session = session
    self.title = title
    self.hovering = hovering
    guard changed else { return }
    if hovering { session.enter(title: title, anchor: self) }
    else { session.leave(anchor: self) }
  }

  func detach() { session?.remove(anchor: self) }
}

/// One hover session and panel per Dock, so moving between icons never restarts the delay.
@MainActor
final class DockTooltipSession: NSObject, ObservableObject {
  private weak var anchor: NSView?
  private weak var owner: NSWindow?
  private var title = ""
  private var ready = false
  private var pendingShow: Task<Void, Never>?
  private var pendingHide: Task<Void, Never>?
  private var panel: DockTooltipPanel?
  private var hosting: NSHostingView<AnyView>?
  private var eventMonitor: Any?

  func enter(title: String, anchor: NSView) {
    guard let window = anchor.window else { return }
    if owner !== window {
      dismiss()
      observe(window)
    }
    pendingShow?.cancel()
    pendingHide?.cancel()
    self.anchor = anchor
    self.title = title
    if ready { show(); return }
    pendingShow = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      self?.show()
    }
  }

  func leave(anchor: NSView) {
    guard self.anchor === anchor else { return }
    self.anchor = nil
    pendingShow?.cancel()
    // Bridge the small gaps between icons without flashing or showing two labels.
    pendingHide?.cancel()
    pendingHide = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
      self?.panel?.orderOut(nil)
    }
  }

  func remove(anchor: NSView) {
    if self.anchor === anchor { dismiss() }
  }

  private func observe(_ window: NSWindow) {
    owner = window
    for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification,
                 NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(windowChanged), name: name, object: window)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(visibilityChanged),
                                          name: NSWindow.didChangeOcclusionStateNotification, object: window)
    NotificationCenter.default.addObserver(self, selector: #selector(windowChanged),
                                          name: NSApplication.didResignActiveNotification, object: nil)
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
      MainActor.assumeIsolated { self?.dismiss() }
      return event
    }
  }

  func dismiss() {
    pendingShow?.cancel()
    pendingHide?.cancel()
    pendingShow = nil
    pendingHide = nil
    anchor = nil
    ready = false
    NotificationCenter.default.removeObserver(self)
    if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    eventMonitor = nil
    if let panel {
      panel.orderOut(nil)
      panel.parent?.removeChildWindow(panel)
    }
    owner = nil
  }

  @objc private func windowChanged(_ notification: Notification) { dismiss() }

  @objc private func visibilityChanged(_ notification: Notification) {
    if owner?.isVisible != true || owner?.occlusionState.contains(.visible) != true { dismiss() }
  }

  private func show() {
    guard let anchor, let window = anchor.window, window.isVisible, !anchor.isHiddenOrHasHiddenAncestor,
          let screen = window.screen else { return }
    let panel = panel ?? DockTooltipPanel()
    self.panel = panel
    panel.appearance = window.effectiveAppearance
    let scheme: ColorScheme = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    let visible = screen.visibleFrame.insetBy(dx: 4, dy: 4)
    let maxTextWidth = max(1, visible.width - DockTooltipLabel.shadowInset * 2 - 28)
    let label = DockTooltipLabel(title: title, maxTextWidth: maxTextWidth)
    let hosting = hosting ?? NSHostingView(rootView: AnyView(label.environment(\.colorScheme, scheme).appLocalized()))
    self.hosting = hosting
    hosting.rootView = AnyView(label.environment(\.colorScheme, scheme).appLocalized())
    let size = hosting.fittingSize
    panel.contentView = hosting
    let anchorFrame = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
    let origin = CGPoint(x: min(max(anchorFrame.midX - size.width / 2, visible.minX), visible.maxX - size.width),
                         y: min(anchorFrame.maxY + 6 - DockTooltipLabel.shadowInset, visible.maxY - size.height))
    hosting.rootView = AnyView(DockTooltipLabel(title: title, maxTextWidth: maxTextWidth,
      tipOffset: anchorFrame.midX - (origin.x + size.width / 2)).environment(\.colorScheme, scheme).appLocalized())
    panel.setFrame(CGRect(origin: origin, size: size), display: true)
    hosting.layoutSubtreeIfNeeded()
    panel.level = window.level
    if panel.parent !== window { window.addChildWindow(panel, ordered: .above) }
    panel.orderFront(nil)
    ready = true
  }
}

private final class DockTooltipPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  init() {
    super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    title = "Augma Dock Tooltip"
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = true
    isReleasedWhenClosed = false
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    setAccessibilityElement(false)
  }
}

private struct DockTooltipLabel: View {
  static let shadowInset: CGFloat = 24
  let title: String
  let maxTextWidth: CGFloat
  var tipOffset: CGFloat = 0

  var body: some View {
    Text(title)
      .font(.system(size: 13))
      .foregroundStyle(.primary)
      .lineLimit(1)
      .truncationMode(.middle)
      .frame(minWidth: 20, maxWidth: maxTextWidth)
      .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 13)
      .glassEffect(.regular, in: DockTooltipShape(tipOffset: tipOffset))
      .padding(Self.shadowInset)
      .fixedSize()
      .accessibilityHidden(true)
  }
}

private struct DockTooltipShape: Shape {
  var tipOffset: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let bottom = rect.maxY - 7
    let radius = (bottom - rect.minY) / 2
    let tipX = min(max(rect.midX + tipOffset, rect.minX + radius + 8), rect.maxX - radius - 8)
    return Path { path in
      path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
      path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius,
                  startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
      path.addLine(to: CGPoint(x: tipX + 10, y: bottom))
      path.addCurve(to: CGPoint(x: tipX + 2, y: rect.maxY - 1),
                    control1: CGPoint(x: tipX + 6, y: bottom), control2: CGPoint(x: tipX + 4, y: rect.maxY - 3))
      path.addQuadCurve(to: CGPoint(x: tipX - 2, y: rect.maxY - 1), control: CGPoint(x: tipX, y: rect.maxY + 1))
      path.addCurve(to: CGPoint(x: tipX - 10, y: bottom),
                    control1: CGPoint(x: tipX - 4, y: rect.maxY - 3), control2: CGPoint(x: tipX - 6, y: bottom))
      path.addLine(to: CGPoint(x: rect.minX + radius, y: bottom))
      path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius,
                  startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
      path.closeSubpath()
    }
  }
}
