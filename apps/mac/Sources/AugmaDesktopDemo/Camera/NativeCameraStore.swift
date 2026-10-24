import AppKit
import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers

/// One app-owned session is shared by the main window and immersive panel.
/// Displaying the feature never requests permission or starts the camera.
@MainActor
final class NativeCameraStore: ObservableObject {
  enum Phase: Equatable { case idle, requestingPermission, starting, running }

  @Published private(set) var phase: Phase = .idle
  @Published private(set) var authorization: NativeCameraAuthorization
  @Published private(set) var devices: [NativeCameraDevice] = []
  @Published private(set) var selectedDeviceID: String?
  @Published private(set) var error: NativeCameraFailure?
  @Published private(set) var photoData: Data?
  @Published private(set) var takingPhoto = false
  @Published private(set) var savingPhoto = false
  @Published private(set) var savedPhotoName: String?
  @Published var mirrored = true

  var previewSession: AVCaptureSession? { engine.previewSession }
  var running: Bool { phase == .running }
  var busy: Bool { phase == .requestingPermission || phase == .starting }

  private let engine: any NativeCameraEngineBackend
  private let permission: any NativeCameraPermissionSource
  private let visibilityDelay: Duration
  private let writePhoto: @Sendable (Data, URL) async throws -> Void
  private var generation = 0
  private var operation: Task<Void, Never>?
  private var hideTask: Task<Void, Never>?
  private var consumers: Set<UUID> = []
  private var lifecycle: [AnyCancellable] = []
  private var active = true
  private var sleeping = false
  private var terminated = false

  init(engine: (any NativeCameraEngineBackend)? = nil,
       permission: (any NativeCameraPermissionSource)? = nil,
       observeLifecycle: Bool = true,
       visibilityDelay: Duration = .milliseconds(350),
       writePhoto: @escaping @Sendable (Data, URL) async throws -> Void = { data, url in
         try await Task.detached(priority: .userInitiated) { try data.write(to: url, options: .atomic) }.value
       }) {
    self.engine = engine ?? NativeCameraEngine()
    self.permission = permission ?? NativeCameraPermission()
    self.visibilityDelay = visibilityDelay
    self.writePhoto = writePhoto
    authorization = self.permission.status
    self.engine.onDevicesChanged = { [weak self] devices in self?.updateDevices(devices) }
    self.engine.onFailure = { [weak self] failure in
      guard let self, self.phase != .idle else { return }
      self.stop()
      self.updateDevices(self.devices)
      self.error = failure
    }
    if observeLifecycle {
      active = NSApp?.isActive ?? true
      NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
        .receive(on: RunLoop.main).sink { [weak self] _ in self?.setActive(false) }.store(in: &lifecycle)
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        .receive(on: RunLoop.main).sink { [weak self] _ in self?.setActive(true) }.store(in: &lifecycle)
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
        .receive(on: RunLoop.main).sink { [weak self] _ in self?.setSleeping(true) }.store(in: &lifecycle)
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        .receive(on: RunLoop.main).sink { [weak self] _ in self?.setSleeping(false) }.store(in: &lifecycle)
      NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        .receive(on: RunLoop.main).sink { [weak self] _ in self?.shutdown() }.store(in: &lifecycle)
    }
  }

  func refreshDevices() async {
    guard !terminated else { return }
    authorization = permission.status
    updateDevices(await engine.devices())
  }

  func start() {
    guard !terminated, active, !sleeping, !consumers.isEmpty, !busy, !running else { return }
    generation += 1
    let request = generation
    error = nil
    authorization = permission.status
    phase = authorization == .notDetermined ? .requestingPermission : .starting
    operation = Task { [weak self] in
      guard let self else { return }
      let authorization = self.permission.status == .notDetermined
        ? await self.permission.request() : self.permission.status
      guard self.isCurrent(request) else { return }
      self.authorization = authorization
      switch authorization {
      case .denied:
        self.phase = .idle
        self.error = .denied
      case .restricted:
        self.phase = .idle
        self.error = .restricted
      case .notDetermined:
        self.phase = .idle
      case .authorized:
        self.phase = .starting
        do {
          let device = try await self.engine.start(deviceID: self.selectedDeviceID)
          guard self.isCurrent(request) else { return }
          self.selectedDeviceID = device.id
          self.phase = .running
        } catch {
          guard self.isCurrent(request) else { return }
          self.engine.stop()
          self.phase = .idle
          self.error = (error as? NativeCameraFailure) ?? .configuration
        }
      }
    }
  }

  func stop() {
    generation += 1
    operation?.cancel()
    operation = nil
    phase = .idle
    takingPhoto = false
    engine.stop()
  }

  func selectDevice(_ id: String) {
    guard devices.contains(where: { $0.id == id }), selectedDeviceID != id else { return }
    let restart = running || busy
    stop()
    selectedDeviceID = id
    error = nil
    if restart { start() }
  }

  func capturePhoto() {
    guard running, !takingPhoto, !savingPhoto else { return }
    let request = generation
    takingPhoto = true
    savedPhotoName = nil
    error = nil
    Task { [weak self] in
      guard let self else { return }
      do {
        let data = try await self.engine.capturePhoto()
        guard self.isCurrent(request), self.running else { return }
        guard !data.isEmpty else { throw NativeCameraFailure.photo }
        self.photoData = data
        self.takingPhoto = false
      } catch {
        guard self.isCurrent(request) else { return }
        self.takingPhoto = false
        self.error = .photo
      }
    }
  }

  func discardPhoto() { photoData = nil; savedPhotoName = nil }

  func savePhoto() {
    guard let photoData, !savingPhoto else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.jpeg]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "Augma-\(Date.now.formatted(.iso8601).replacingOccurrences(of: ":", with: "-" )).jpg"
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      Task { @MainActor [weak self] in await self?.savePhoto(photoData, to: url) }
    }
  }

  /// The Save panel is the sole production caller. Injection keeps disk errors
  /// testable without presenting UI or writing test artifacts to a user folder.
  func savePhoto(_ data: Data, to url: URL) async {
    guard !savingPhoto, !data.isEmpty else { return }
    savingPhoto = true
    error = nil
    defer { savingPhoto = false }
    do {
      try await writePhoto(data, url)
      savedPhotoName = url.lastPathComponent
    } catch { self.error = .save }
  }

  func openPrivacySettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
    NSWorkspace.shared.open(url)
  }

  func setConsumerVisible(_ id: UUID, _ visible: Bool) {
    if visible {
      consumers.insert(id)
      hideTask?.cancel()
      hideTask = nil
    } else {
      consumers.remove(id)
      guard consumers.isEmpty else { return }
      hideTask?.cancel()
      hideTask = Task { [weak self] in
        guard let self else { return }
        do { try await Task.sleep(for: self.visibilityDelay) } catch { return }
        guard self.consumers.isEmpty else { return }
        self.stop()
      }
    }
  }

  func setActive(_ value: Bool) {
    active = value
    if !value { stop() }
    else { authorization = permission.status }
  }

  func setSleeping(_ value: Bool) { sleeping = value; if value { stop() } }

  func shutdown() {
    terminated = true
    hideTask?.cancel()
    consumers.removeAll()
    stop()
  }

  private func isCurrent(_ request: Int) -> Bool {
    generation == request && !terminated && active && !sleeping
  }

  private func updateDevices(_ devices: [NativeCameraDevice]) {
    self.devices = devices
    if selectedDeviceID == nil { selectedDeviceID = devices.first?.id }
    else if let selectedDeviceID, !devices.contains(where: { $0.id == selectedDeviceID }), phase == .idle {
      self.selectedDeviceID = devices.first?.id
    }
  }

  deinit { operation?.cancel(); hideTask?.cancel() }
}
