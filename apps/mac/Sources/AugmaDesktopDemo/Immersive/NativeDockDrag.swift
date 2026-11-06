import AppKit
import SwiftUI

/// Icon geometry follows the available width, including drag targets and previews.
struct NativeDockRow<Icon: View, Empty: View>: View {
  @ObservedObject var store: NativeDockStore
  let viewport: CGRect
  let availableWidth: CGFloat
  @ViewBuilder let icon: (NativeDockItem, CGFloat) -> Icon
  @ViewBuilder let empty: () -> Empty
  @Namespace private var space
  @State private var frames: [String: CGRect] = [:]
  @State private var rowFrame = CGRect.zero
  @State private var dragPosition: CGPoint?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var metrics: NativeDockMetrics {
    NativeDockMetrics(itemCount: store.displayedItems.count, availableWidth: availableWidth)
  }

  var body: some View {
    HStack(spacing: metrics.spacing) {
      ForEach(store.displayedItems) { item in
        icon(item, metrics.iconSize)
          .opacity(store.draggedItem == item ? 0.35 : 1)
          .modifier(NativeDockDrag(item: item, store: store, space: space, frames: frames,
                                   bounds: visibleBounds, position: $dragPosition, reduceMotion: reduceMotion))
          .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { frames[item.id] = $0 }
      }
      if store.items.isEmpty { empty() }
    }
    .padding(.horizontal, metrics.horizontalPadding).padding(.vertical, metrics.verticalPadding)
    .coordinateSpace(name: space)
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rowFrame = $0 }
    .overlay(alignment: .topLeading) {
      if let dragPosition, let item = store.draggedItem {
        icon(item, metrics.iconSize)
          .allowsHitTesting(false).accessibilityHidden(true)
          .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
          .position(dragPosition)
      }
    }
    .onChange(of: store.draggedItem) { _, item in
      if item == nil { dragPosition = nil }
    }
    .onChange(of: availableWidth) { _, _ in
      store.cancelDrag()
    }
    .background(NativeDockCancellation {
      guard store.draggedItem != nil else { return false }
      store.cancelDrag()
      dragPosition = nil
      return true
    })
  }

  private var visibleBounds: CGRect {
    guard !viewport.isEmpty, !rowFrame.isEmpty else { return CGRect(origin: .zero, size: rowFrame.size) }
    return rowFrame.intersection(viewport).offsetBy(dx: -rowFrame.minX, dy: -rowFrame.minY)
  }
}

private struct NativeDockDrag: ViewModifier {
  let item: NativeDockItem
  @ObservedObject var store: NativeDockStore
  let space: Namespace.ID
  let frames: [String: CGRect]
  let bounds: CGRect
  @Binding var position: CGPoint?
  let reduceMotion: Bool
  @GestureState private var active = false
  @State private var started = false
  @State private var slots: [CGRect] = []

  func body(content: Content) -> some View {
    content
      .highPriorityGesture(
        DragGesture(minimumDistance: 5, coordinateSpace: .named(space))
          .updating($active) { _, active, _ in active = true }
          .onChanged { value in
            if !started {
              started = true
              slots = store.displayedItems.compactMap { frames[$0.id] }.sorted { $0.midX < $1.midX }
              store.beginDrag(item)
            }
            guard store.draggedItem?.id == item.id else { return }
            position = value.location
            preview(at: value.location)
          }
          .onEnded { value in
            if store.draggedItem?.id == item.id {
              if bounds.contains(value.location) {
                // A fast drag may release beyond its last mouse-moved event.
                preview(at: value.location)
                store.commitDrop()
              } else {
                store.cancelDrag()
              }
            }
            clearGesture()
          }
      )
      .onChange(of: active) { _, active in
        guard !active else { return }
        if store.draggedItem?.id == item.id { store.cancelDrag() }
        clearGesture()
      }
  }

  private func preview(at point: CGPoint) {
    guard bounds.contains(point),
          let index = slots.indices.min(by: { abs(slots[$0].midX - point.x) < abs(slots[$1].midX - point.x) }),
          store.displayedItems.indices.contains(index) else { return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
      store.previewMove(over: store.displayedItems[index])
    }
  }

  private func clearGesture() {
    position = nil
    started = false
    slots = []
  }
}

/// Escape must cancel a drag before the immersive panel treats it as an exit command.
private struct NativeDockCancellation: NSViewRepresentable {
  let cancel: () -> Bool

  func makeNSView(context: Context) -> DockCancellationView { DockCancellationView() }
  func updateNSView(_ view: DockCancellationView, context: Context) { view.cancel = cancel }
  static func dismantleNSView(_ view: DockCancellationView, coordinator: ()) { view.stop() }
}

private final class DockCancellationView: NSView {
  var cancel: () -> Bool = { false }
  private var monitor: Any?

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    stop()
    guard window != nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, event.window === self.window, event.keyCode == 53,
            event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return event }
      return self.cancel() ? nil : event
    }
  }

  func stop() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
  }
}
