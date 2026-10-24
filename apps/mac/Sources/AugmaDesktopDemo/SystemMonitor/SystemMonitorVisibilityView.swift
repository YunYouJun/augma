import AppKit
import SwiftUI

/// SwiftUI's onDisappear does not fire when its window is minimized, hidden or occluded.
struct SystemMonitorVisibilityView: NSViewRepresentable {
  var includeWhileApplicationHidden = false
  let onChange: (Bool) -> Void

  func makeNSView(context: Context) -> MonitorWindowProbe {
    let view = MonitorWindowProbe()
    view.includeWhileApplicationHidden = includeWhileApplicationHidden
    view.onChange = onChange
    return view
  }

  func updateNSView(_ view: MonitorWindowProbe, context: Context) {
    view.includeWhileApplicationHidden = includeWhileApplicationHidden
    view.onChange = onChange
    // Do not publish observable state during a SwiftUI view update.
    view.scheduleUpdate()
  }

  static func dismantleNSView(_ view: MonitorWindowProbe, coordinator: ()) {
    view.stop()
  }
}

final class MonitorWindowProbe: NSView {
  var includeWhileApplicationHidden = false
  var onChange: ((Bool) -> Void)?
  private var lastVisible: Bool?
  private var stopped = false

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    NotificationCenter.default.removeObserver(self)
    stopped = false
    if let window {
      for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                   NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
        NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: name, object: window)
      }
      for name in [NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
        NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: name, object: NSApp)
      }
    }
    scheduleUpdate()
  }

  func scheduleUpdate() {
    Task { @MainActor [weak self] in self?.updateVisibility() }
  }

  @objc private func windowChanged(_ notification: Notification) {
    if notification.name == NSWindow.willCloseNotification { stop() }
    else { scheduleUpdate() }
  }

  private func updateVisibility() {
    guard !stopped else { return }
    let visible = window.map {
      $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible)
        && (includeWhileApplicationHidden || !NSApp.isHidden)
    } ?? false
    guard lastVisible != visible else { return }
    lastVisible = visible
    onChange?(visible)
  }

  func stop() {
    stopped = true
    NotificationCenter.default.removeObserver(self)
    if lastVisible != false {
      let callback = onChange
      Task { @MainActor in callback?(false) }
    }
    lastVisible = false
  }

  deinit { NotificationCenter.default.removeObserver(self) }
}
