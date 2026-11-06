import AppKit
import SwiftUI

/// A separate, noninteractive window lets the label extend above the compact Dock panel.
struct DockTooltip: ViewModifier {
  let title: String
  @State private var hovering = false

  func body(content: Content) -> some View {
    content
      .background { DockTooltipAnchor(title: title, hovering: hovering) }
      .onHover { hovering = $0 }
      .onDisappear { hovering = false }
  }
}

private struct DockTooltipAnchor: NSViewRepresentable {
  let title: String
  let hovering: Bool

  func makeNSView(context: Context) -> DockTooltipAnchorView { DockTooltipAnchorView() }

  func updateNSView(_ view: DockTooltipAnchorView, context: Context) {
    view.update(title: title, hovering: hovering)
  }

  static func dismantleNSView(_ view: DockTooltipAnchorView, coordinator: ()) {
    view.dismiss()
  }
}

private final class DockTooltipAnchorView: NSView {
  private var title = ""
  private var hovering = false
  private var pendingShow: Task<Void, Never>?
  private var panel: DockTooltipPanel?
  private var eventMonitor: Any?

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    dismiss()
    NotificationCenter.default.removeObserver(self)
    guard let window else { return }
    for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification,
                 NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(windowChanged), name: name, object: window)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(visibilityChanged),
                                          name: NSWindow.didChangeOcclusionStateNotification, object: window)
    NotificationCenter.default.addObserver(self, selector: #selector(windowChanged),
                                          name: NSApplication.didResignActiveNotification, object: nil)
  }

  func update(title: String, hovering: Bool) {
    if self.title != title {
      self.title = title
      if panel?.isVisible == true { show() }
    }
    guard self.hovering != hovering else { return }
    self.hovering = hovering
    dismiss()
    guard hovering else { return }
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
      Task { @MainActor [weak self] in self?.dismiss() }
      return event
    }
    pendingShow = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      self?.show()
    }
  }

  func dismiss() {
    pendingShow?.cancel()
    pendingShow = nil
    if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    eventMonitor = nil
    panel?.orderOut(nil)
  }

  @objc private func windowChanged(_ notification: Notification) { dismiss() }

  @objc private func visibilityChanged(_ notification: Notification) {
    if window?.isVisible != true || window?.occlusionState.contains(.visible) != true { dismiss() }
  }

  private func show() {
    guard hovering, let window, window.isVisible, !isHiddenOrHasHiddenAncestor,
          let screen = window.screen else { return }
    let panel = panel ?? DockTooltipPanel()
    self.panel = panel
    panel.appearance = window.effectiveAppearance
    let hosting = NSHostingView(rootView: DockTooltipLabel(title: title).appLocalized())
    let size = hosting.fittingSize
    panel.contentView = hosting
    let anchor = window.convertToScreen(convert(bounds, to: nil))
    let visible = screen.visibleFrame.insetBy(dx: 4, dy: 4)
    let origin = CGPoint(x: min(max(anchor.midX - size.width / 2, visible.minX), visible.maxX - size.width),
                         y: min(anchor.maxY + 2, visible.maxY - size.height))
    panel.setFrame(CGRect(origin: origin, size: size), display: true)
    panel.level = window.level
    window.addChildWindow(panel, ordered: .above)
    panel.orderFront(nil)
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
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(.primary)
      .lineLimit(1)
      .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 12)
      .background(.regularMaterial, in: DockTooltipShape())
      .overlay { DockTooltipShape().strokeBorder(.primary.opacity(0.1), lineWidth: 0.5) }
      .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
      .padding(8)
      .fixedSize()
      .accessibilityHidden(true)
  }
}

private struct DockTooltipShape: InsettableShape {
  var insetAmount: CGFloat = 0

  func inset(by amount: CGFloat) -> some InsettableShape {
    var shape = self
    shape.insetAmount += amount
    return shape
  }

  func path(in rect: CGRect) -> Path {
    let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
    let bottom = rect.maxY - 6
    let radius: CGFloat = 10
    return Path { path in
      path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
      path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: bottom - radius))
      path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: bottom), control: CGPoint(x: rect.maxX, y: bottom))
      path.addLine(to: CGPoint(x: rect.midX + 7, y: bottom))
      path.addLine(to: CGPoint(x: rect.midX + 2, y: rect.maxY - 1))
      path.addQuadCurve(to: CGPoint(x: rect.midX - 2, y: rect.maxY - 1), control: CGPoint(x: rect.midX, y: rect.maxY + 1))
      path.addLine(to: CGPoint(x: rect.midX - 7, y: bottom))
      path.addLine(to: CGPoint(x: rect.minX + radius, y: bottom))
      path.addQuadCurve(to: CGPoint(x: rect.minX, y: bottom - radius), control: CGPoint(x: rect.minX, y: bottom))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
      path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
      path.closeSubpath()
    }
  }
}
