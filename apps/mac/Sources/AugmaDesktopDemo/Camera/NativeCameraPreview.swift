import AppKit
import AVFoundation
import SwiftUI

struct NativeCameraPreview: NSViewRepresentable {
  let session: AVCaptureSession?
  let mirrored: Bool

  func makeNSView(context: Context) -> CameraPreviewSurface { CameraPreviewSurface() }

  func updateNSView(_ view: CameraPreviewSurface, context: Context) {
    if view.preview.session !== session { view.preview.session = session }
    if let connection = view.preview.connection, connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = mirrored
    }
  }

  static func dismantleNSView(_ view: CameraPreviewSurface, coordinator: ()) {
    // Detaching a surface never stops the shared capture session.
    view.preview.session = nil
  }
}

final class CameraPreviewSurface: NSView {
  let preview = AVCaptureVideoPreviewLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    preview.videoGravity = .resizeAspect
    layer?.backgroundColor = NSColor.black.cgColor
    layer?.addSublayer(preview)
  }

  required init?(coder: NSCoder) { nil }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    preview.frame = bounds
    CATransaction.commit()
  }
}

/// SwiftUI disappearance and native window visibility both contribute to whether
/// capture may remain active. The store debounces the main/immersive handoff.
struct NativeCameraVisibilityProbe: NSViewRepresentable {
  let store: NativeCameraStore
  let consumer: UUID

  func makeNSView(context: Context) -> CameraVisibilitySurface {
    CameraVisibilitySurface(store: store, consumer: consumer)
  }
  func updateNSView(_ nsView: CameraVisibilitySurface, context: Context) { nsView.refresh() }
  static func dismantleNSView(_ view: CameraVisibilitySurface, coordinator: ()) { view.stop() }
}

final class CameraVisibilitySurface: NSView {
  private weak var store: NativeCameraStore?
  private let consumer: UUID
  private var observers: [NSObjectProtocol] = []
  private var lastVisible: Bool?

  init(store: NativeCameraStore, consumer: UUID) {
    self.store = store
    self.consumer = consumer
    super.init(frame: .zero)
  }
  required init?(coder: NSCoder) { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    clearObservers()
    if let window {
      for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                   NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
          Task { @MainActor [weak self] in self?.refresh() }
        })
      }
    }
    refresh()
  }

  override func viewDidHide() { super.viewDidHide(); refresh() }
  override func viewDidUnhide() { super.viewDidUnhide(); refresh() }

  func refresh() {
    let visible = window.map { $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) } == true
      && !isHiddenOrHasHiddenAncestor
    guard visible != lastVisible else { return }
    lastVisible = visible
    let consumer = consumer
    Task { @MainActor [weak store] in store?.setConsumerVisible(consumer, visible) }
  }

  func stop() {
    clearObservers()
    lastVisible = false
    let consumer = consumer
    Task { @MainActor [weak store] in store?.setConsumerVisible(consumer, false) }
  }

  private func clearObservers() {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers.removeAll()
  }
}
