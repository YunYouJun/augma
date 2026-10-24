import AppKit
import Combine
import Foundation

/// Window-owned state shared by the main and immersive RealityKit presentations.
/// A scan is a finite simulation. It never starts a camera or reads spatial sensors.
@MainActor
final class NativeSpaceStore: ObservableObject {
  let applications: ApplicationDistrictStore
  let projects: ProjectWorkspaceStore
  @Published var selectedApplicationID: String?
  @Published var selectedProjectID: UUID?
  @Published private(set) var sceneID: NativeSpaceSceneID = .garden
  @Published private(set) var selectedID = "terrace"
  @Published private(set) var scanning = false
  @Published private(set) var scanProgress: Double = 0
  @Published private(set) var pinnedLandmarkID: String?
  @Published private(set) var routeStep: Int?
  @Published private(set) var viewYaw: Double = 0
  @Published private(set) var viewPitch: Double = -0.15
  @Published private(set) var viewScale: Double = 1

  var scene: NativeSpaceScene { NativeSpaceScene.scene(for: sceneID) }
  var selected: NativeSpaceLandmark { scene.landmarks.first { $0.id == selectedID } ?? scene.landmarks[0] }
  var pinned: Bool { pinnedLandmarkID == selectedID }
  var routeProgress: Double { Double(routeStep ?? 0) / 4 * 100 }
  var remaining: Int { Int((Double(selected.distance) * (1 - routeProgress / 100)).rounded()) }

  private let uptime: () -> TimeInterval
  private let autoTick: Bool
  private var scanStartedAt: TimeInterval?
  private var scanGeneration: UInt64 = 0
  private var scanTask: Task<Void, Never>?
  private var lifecycle: [AnyCancellable] = []
  private var sleeping = false
  private var terminated = false

  init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       autoTick: Bool = true, observeLifecycle: Bool = true, applications: ApplicationDistrictStore? = nil,
       projects: ProjectWorkspaceStore? = nil) {
    self.applications = applications ?? ApplicationDistrictStore()
    self.projects = projects ?? ProjectWorkspaceStore()
    if let applications, !applications.buildings.isEmpty {
      sceneID = .workspace
      selectedID = "workspace-center"
    }
    if let projects, !projects.regions.isEmpty {
      sceneID = .projects
      selectedID = "project-center"
      selectedProjectID = projects.regions.first?.id
    }
    self.uptime = uptime
    self.autoTick = autoTick
    if observeLifecycle {
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
        .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification))
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(true) }.store(in: &lifecycle)
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification))
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(false) }.store(in: &lifecycle)
    }
  }

  func selectScene(_ id: NativeSpaceSceneID) {
    guard !terminated, id != sceneID else { return }
    cancelScan()
    sceneID = id
    selectedID = scene.landmarks[0].id
    scanProgress = 0
    pinnedLandmarkID = nil
    routeStep = nil
    resetView()
  }

  func selectLandmark(_ id: String) {
    guard !terminated, id != selectedID, scene.landmarks.contains(where: { $0.id == id }) else { return }
    selectedID = id
    routeStep = nil
    // Pinning is attached to a particular landmark, not to whichever is selected.
  }

  func scan() {
    guard !terminated, !sleeping, !scanning else { return }
    let now = uptime()
    guard now.isFinite else { return }
    stopScanTask()
    scanStartedAt = now
    scanProgress = 0
    pinnedLandmarkID = nil
    scanning = true
    guard autoTick else { return }
    let generation = scanGeneration
    scanTask = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(50)) }
        catch { return }
        guard let self, !Task.isCancelled, generation == self.scanGeneration, self.scanning else { return }
        self.refreshScan()
      }
    }
  }

  /// Also lets tests advance the finite simulation with a deterministic clock.
  func refreshScan() {
    guard !terminated, scanning, let scanStartedAt else { return }
    let now = uptime()
    guard now.isFinite else { return }
    let next = min(100, max(scanProgress, max(0, now - scanStartedAt) / 2 * 100))
    if next != scanProgress { scanProgress = next }
    if next == 100 {
      scanning = false
      stopScanTask()
    }
  }

  func cancelScan() {
    if scanning { scanning = false }
    stopScanTask()
  }

  func togglePin() {
    guard !terminated, !scanning, scanProgress == 100 else { return }
    pinnedLandmarkID = pinned ? nil : selectedID
  }

  func startRoute() {
    guard !terminated else { return }
    routeStep = 0
  }

  func advanceRoute() {
    guard !terminated, let routeStep, routeStep < 4 else { return }
    self.routeStep = routeStep + 1
  }

  func cancelRoute() {
    guard routeStep != nil else { return }
    routeStep = nil
  }

  func setView(yaw: Double, pitch: Double, scale: Double) {
    guard !terminated, yaw.isFinite, pitch.isFinite, scale.isFinite else { return }
    let revolution = Double.pi * 2
    var normalizedYaw = yaw.truncatingRemainder(dividingBy: revolution)
    if normalizedYaw > .pi { normalizedYaw -= revolution }
    if normalizedYaw < -.pi { normalizedYaw += revolution }
    let normalizedPitch = min(0.7, max(-0.7, pitch))
    let normalizedScale = min(1.6, max(0.65, scale))
    if normalizedYaw != viewYaw { viewYaw = normalizedYaw }
    if normalizedPitch != viewPitch { viewPitch = normalizedPitch }
    if normalizedScale != viewScale { viewScale = normalizedScale }
  }

  func resetView() { setView(yaw: 0, pitch: -0.15, scale: 1) }

  func setSleeping(_ value: Bool) {
    guard !terminated, sleeping != value else { return }
    sleeping = value
    if value { cancelScan() }
  }

  func shutdown() {
    guard !terminated else { return }
    cancelScan()
    terminated = true
    lifecycle.removeAll()
  }

  private func stopScanTask() {
    scanGeneration &+= 1
    scanTask?.cancel()
    scanTask = nil
    scanStartedAt = nil
  }

  deinit { scanTask?.cancel() }
}
