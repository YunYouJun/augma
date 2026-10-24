import AVFoundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeCameraTests: XCTestCase {
  func testLoadingAndDiscoveryNeverRequestPermissionOrOpenCapture() async {
    let (store, engine, permission, consumer) = fixture(.notDetermined)
    await store.refreshDevices()
    XCTAssertEqual(store.devices.count, 2)
    XCTAssertEqual(store.selectedDeviceID, "built-in")
    XCTAssertEqual(permission.requests, 0)
    XCTAssertEqual(engine.starts, [])
    XCTAssertEqual(store.phase, .idle)
    store.setConsumerVisible(consumer, false)
    store.shutdown()
  }

  func testExplicitStartHandlesDeniedAndRestrictedWithoutOpeningHardware() async {
    for status in [NativeCameraAuthorization.denied, .restricted] {
      let (store, engine, permission, _) = fixture(status)
      store.start()
      await settle()
      XCTAssertEqual(store.error, status == .denied ? .denied : .restricted)
      XCTAssertEqual(store.phase, .idle)
      XCTAssertEqual(permission.requests, 0)
      XCTAssertTrue(engine.starts.isEmpty)
      store.shutdown()
    }
  }

  func testPermissionRequestIsExplicitAndStopInvalidatesItsPendingResult() async {
    let (store, engine, permission, _) = fixture(.notDetermined)
    permission.deferRequest = true
    store.start()
    await settle()
    XCTAssertEqual(store.phase, .requestingPermission)
    XCTAssertEqual(permission.requests, 1)
    store.start()
    XCTAssertEqual(permission.requests, 1)
    store.stop()
    permission.resolve(.authorized)
    await settle()
    XCTAssertEqual(store.phase, .idle)
    XCTAssertTrue(engine.starts.isEmpty)
    store.start()
    await settle()
    XCTAssertTrue(store.running)
    XCTAssertEqual(engine.starts.count, 1)
    store.shutdown()
  }

  func testStoppingPendingStartPreventsStaleCompletionFromPublishingRunning() async {
    let (store, engine, _, _) = fixture()
    engine.deferStart = true
    store.start()
    await settle()
    XCTAssertEqual(store.phase, .starting)
    store.stop()
    engine.resolveStart()
    await settle()
    XCTAssertFalse(store.running)
    XCTAssertEqual(store.phase, .idle)
    XCTAssertGreaterThan(engine.stops, 0)
    store.shutdown()
  }

  func testUnavailableHardwareClearsBusyAndAllowsAnExplicitRetry() async {
    let (store, engine, _, _) = fixture()
    engine.startFailure = .unavailable
    store.start()
    await settle()
    XCTAssertEqual(store.phase, .idle)
    XCTAssertEqual(store.error, .unavailable)
    engine.startFailure = nil
    store.start()
    await settle()
    XCTAssertTrue(store.running)
    XCTAssertNil(store.error)
    store.shutdown()
  }

  func testDeviceSelectionSwitchesRunningSessionAndPreservesStoppedIntent() async {
    let (store, engine, _, _) = fixture()
    await store.refreshDevices()
    store.start()
    await settle()
    store.selectDevice("external")
    await settle()
    XCTAssertEqual(engine.starts, ["built-in", "external"])
    XCTAssertEqual(store.selectedDeviceID, "external")
    XCTAssertTrue(store.running)
    store.selectDevice("unknown")
    XCTAssertEqual(store.selectedDeviceID, "external")
    store.stop()
    store.selectDevice("built-in")
    await settle()
    XCTAssertEqual(engine.starts.count, 2)
    XCTAssertFalse(store.running)
    store.shutdown()
  }

  func testVisibilityHandoffKeepsSessionButTrulyHiddenConsumerStopsIt() async throws {
    let (store, engine, _, mainConsumer) = fixture(visibilityDelay: .milliseconds(15))
    store.start()
    await settle()
    let immersiveConsumer = UUID()
    store.setConsumerVisible(mainConsumer, false)
    store.setConsumerVisible(immersiveConsumer, true)
    try await Task.sleep(for: .milliseconds(40))
    XCTAssertTrue(store.running)
    XCTAssertEqual(engine.starts.count, 1)
    XCTAssertEqual(engine.stops, 0)
    store.setConsumerVisible(immersiveConsumer, false)
    try await Task.sleep(for: .milliseconds(40))
    XCTAssertFalse(store.running)
    XCTAssertEqual(engine.stops, 1)
    store.setConsumerVisible(mainConsumer, true)
    await settle()
    XCTAssertEqual(engine.starts.count, 1)
    store.shutdown()
  }

  func testBackgroundSleepAndShutdownNeverAutomaticallyResumeCapture() async {
    let (store, engine, _, _) = fixture()
    store.start()
    await settle()
    XCTAssertTrue(store.running)
    store.setActive(false)
    XCTAssertFalse(store.running)
    store.start()
    await settle()
    XCTAssertEqual(engine.starts.count, 1)
    store.setActive(true)
    await settle()
    XCTAssertEqual(engine.starts.count, 1)
    store.start()
    await settle()
    store.setSleeping(true)
    XCTAssertFalse(store.running)
    store.setSleeping(false)
    await settle()
    XCTAssertEqual(engine.starts.count, 2)
    store.shutdown()
    store.start()
    await settle()
    XCTAssertEqual(engine.starts.count, 2)
  }

  func testRuntimeAndDisconnectErrorsStopAndCanBeExplicitlyRetried() async {
    let (store, engine, _, _) = fixture()
    store.start()
    await settle()
    engine.onDevicesChanged?([NativeCameraDevice(id: "external", name: "USB Camera")])
    engine.onFailure?(.disconnected)
    XCTAssertFalse(store.running)
    XCTAssertEqual(store.error, .disconnected)
    XCTAssertEqual(store.selectedDeviceID, "external")
    store.start()
    await settle()
    XCTAssertTrue(store.running)
    XCTAssertNil(store.error)
    engine.onFailure?(.runtime)
    XCTAssertEqual(store.error, .runtime)
    XCTAssertFalse(store.running)
    store.shutdown()
  }

  func testPhotoCaptureIsExplicitAndFailuresDoNotReplacePreviousPhoto() async {
    let (store, engine, _, _) = fixture()
    store.capturePhoto()
    XCTAssertEqual(engine.photos, 0)
    store.start()
    await settle()
    store.capturePhoto()
    await settle()
    XCTAssertEqual(store.photoData, Data([1, 2, 3]))
    XCTAssertFalse(store.takingPhoto)
    engine.photoFailure = true
    store.capturePhoto()
    await settle()
    XCTAssertEqual(store.error, .photo)
    XCTAssertEqual(store.photoData, Data([1, 2, 3]))
    XCTAssertTrue(store.running)
    store.discardPhoto()
    XCTAssertNil(store.photoData)
    store.shutdown()
  }

  func testPhotoCompletionAfterStopIsIgnored() async {
    let (store, engine, _, _) = fixture()
    store.start()
    await settle()
    engine.deferPhoto = true
    store.capturePhoto()
    await settle()
    store.stop()
    engine.resolvePhoto()
    await settle()
    XCTAssertNil(store.photoData)
    XCTAssertFalse(store.takingPhoto)
    XCTAssertNil(store.error)
    store.shutdown()
  }

  func testSaveFailureIsReportedWithoutLosingPhotoOrStartingCamera() async {
    let engine = CameraTestEngine()
    let store = NativeCameraStore(engine: engine, permission: CameraTestPermission(.authorized), observeLifecycle: false,
      writePhoto: { _, _ in throw NativeCameraFailure.save })
    await store.savePhoto(Data([1]), to: URL(fileURLWithPath: "/unused/test.jpg"))
    XCTAssertEqual(store.error, .save)
    XCTAssertFalse(store.savingPhoto)
    XCTAssertNil(store.savedPhotoName)
    XCTAssertTrue(engine.starts.isEmpty)
    store.shutdown()
  }

  private func fixture(_ authorization: NativeCameraAuthorization = .authorized,
                       visibilityDelay: Duration = .milliseconds(350)) -> (NativeCameraStore, CameraTestEngine, CameraTestPermission, UUID) {
    let engine = CameraTestEngine()
    let permission = CameraTestPermission(authorization)
    let store = NativeCameraStore(engine: engine, permission: permission, observeLifecycle: false, visibilityDelay: visibilityDelay)
    let consumer = UUID()
    store.setConsumerVisible(consumer, true)
    return (store, engine, permission, consumer)
  }

  private func settle() async { for _ in 0..<12 { await Task.yield() } }
}

@MainActor
private final class CameraTestPermission: NativeCameraPermissionSource {
  var status: NativeCameraAuthorization
  var requests = 0
  var deferRequest = false
  private var pending: CheckedContinuation<NativeCameraAuthorization, Never>?

  init(_ status: NativeCameraAuthorization) { self.status = status }
  func request() async -> NativeCameraAuthorization {
    requests += 1
    if deferRequest { return await withCheckedContinuation { pending = $0 } }
    return status
  }
  func resolve(_ authorization: NativeCameraAuthorization) {
    status = authorization
    pending?.resume(returning: authorization)
    pending = nil
  }
}

@MainActor
private final class CameraTestEngine: NativeCameraEngineBackend {
  let previewSession: AVCaptureSession? = nil
  var onDevicesChanged: (@MainActor @Sendable ([NativeCameraDevice]) -> Void)?
  var onFailure: (@MainActor @Sendable (NativeCameraFailure) -> Void)?
  var starts: [String] = []
  var stops = 0
  var photos = 0
  var deferStart = false
  var deferPhoto = false
  var photoFailure = false
  var startFailure: NativeCameraFailure?
  private var pendingStart: CheckedContinuation<NativeCameraDevice, Error>?
  private var pendingPhoto: CheckedContinuation<Data, Error>?
  private let builtIn = NativeCameraDevice(id: "built-in", name: "FaceTime HD Camera")
  private let external = NativeCameraDevice(id: "external", name: "USB Camera")

  func devices() async -> [NativeCameraDevice] { [builtIn, external] }
  func start(deviceID: String?) async throws -> NativeCameraDevice {
    starts.append(deviceID ?? "built-in")
    if let startFailure { throw startFailure }
    if deferStart { return try await withCheckedThrowingContinuation { pendingStart = $0 } }
    return deviceID == external.id ? external : builtIn
  }
  func stop() { stops += 1 }
  func capturePhoto() async throws -> Data {
    photos += 1
    if deferPhoto { return try await withCheckedThrowingContinuation { pendingPhoto = $0 } }
    if photoFailure { throw NativeCameraFailure.photo }
    return Data([1, 2, 3])
  }
  func resolveStart() { pendingStart?.resume(returning: builtIn); pendingStart = nil }
  func resolvePhoto() { pendingPhoto?.resume(returning: Data([1, 2, 3])); pendingPhoto = nil }
}
