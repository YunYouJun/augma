@preconcurrency import AVFoundation
import Foundation

/// The session is only mutated on the worker's serial queue. The main actor
/// passes its identity to AVCaptureVideoPreviewLayer, which AVFoundation owns.
@MainActor
final class NativeCameraEngine: NativeCameraEngineBackend {
  private let worker: NativeCameraSessionWorker
  var previewSession: AVCaptureSession? { worker.session }
  var onDevicesChanged: (@MainActor @Sendable ([NativeCameraDevice]) -> Void)?
  var onFailure: (@MainActor @Sendable (NativeCameraFailure) -> Void)?

  init() {
    worker = NativeCameraSessionWorker()
    worker.installCallbacks(devices: { [weak self] devices in
      Task { @MainActor [weak self] in self?.onDevicesChanged?(devices) }
    }, failure: { [weak self] failure in
      Task { @MainActor [weak self] in self?.onFailure?(failure) }
    })
  }

  func devices() async -> [NativeCameraDevice] { await worker.devices() }
  func start(deviceID: String?) async throws -> NativeCameraDevice {
    try await worker.start(deviceID: deviceID)
  }
  func stop() { worker.stop() }
  func capturePhoto() async throws -> Data { try await worker.capturePhoto() }
}

private final class NativeCameraSessionWorker: @unchecked Sendable {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "com.augma.camera.capture", qos: .userInitiated)
  private let photoOutput = AVCapturePhotoOutput()
  private var input: AVCaptureDeviceInput?
  private var photos: [Int64: NativeCameraPhotoDelegate] = [:]
  private var observers: [NSObjectProtocol] = []
  private var onDevicesChanged: (@Sendable ([NativeCameraDevice]) -> Void)?
  private var onFailure: (@Sendable (NativeCameraFailure) -> Void)?

  init() {
    let center = NotificationCenter.default
    for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
      observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
        self?.queue.async { [weak self] in
          guard let self else { return }
          let devices = self.discover()
          self.onDevicesChanged?(devices.map(Self.describe))
          if let input = self.input, !devices.contains(where: { $0.uniqueID == input.device.uniqueID }) {
            self.stopOnQueue()
            self.onFailure?(.disconnected)
          }
        }
      })
    }
    for (name, failure) in [(AVCaptureSession.runtimeErrorNotification, NativeCameraFailure.runtime),
                            (AVCaptureSession.wasInterruptedNotification, .interrupted)] {
      observers.append(center.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
        self?.queue.async { [weak self] in
          guard let self else { return }
          self.stopOnQueue()
          self.onFailure?(failure)
        }
      })
    }
  }

  func installCallbacks(devices: @escaping @Sendable ([NativeCameraDevice]) -> Void,
                        failure: @escaping @Sendable (NativeCameraFailure) -> Void) {
    queue.async {
      self.onDevicesChanged = devices
      self.onFailure = failure
    }
  }

  func devices() async -> [NativeCameraDevice] {
    await withCheckedContinuation { continuation in
      queue.async { continuation.resume(returning: self.discover().map(Self.describe)) }
    }
  }

  func start(deviceID: String?) async throws -> NativeCameraDevice {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        do {
          self.stopOnQueue()
          let devices = self.discover()
          let device: AVCaptureDevice?
          if let deviceID { device = devices.first { $0.uniqueID == deviceID } }
          else { device = devices.first }
          guard let device else { throw NativeCameraFailure.unavailable }
          let input = try AVCaptureDeviceInput(device: device)
          self.session.beginConfiguration()
          for previous in self.session.inputs { self.session.removeInput(previous) }
          if self.session.canSetSessionPreset(.photo) { self.session.sessionPreset = .photo }
          guard self.session.canAddInput(input) else {
            self.session.commitConfiguration()
            throw NativeCameraFailure.configuration
          }
          self.session.addInput(input)
          if !self.session.outputs.contains(self.photoOutput) {
            guard self.session.canAddOutput(self.photoOutput) else {
              self.session.removeInput(input)
              self.session.commitConfiguration()
              throw NativeCameraFailure.configuration
            }
            self.session.addOutput(self.photoOutput)
          }
          self.input = input
          self.session.commitConfiguration()
          self.session.startRunning()
          guard self.session.isRunning else { throw NativeCameraFailure.runtime }
          continuation.resume(returning: Self.describe(device))
        } catch {
          self.stopOnQueue()
          continuation.resume(throwing: (error as? NativeCameraFailure) ?? .configuration)
        }
      }
    }
  }

  func stop() { queue.async { self.stopOnQueue() } }

  func capturePhoto() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      queue.async { [self] in
        guard self.session.isRunning, self.photoOutput.connection(with: .video)?.isActive == true,
              self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) else {
          continuation.resume(throwing: NativeCameraFailure.photo)
          return
        }
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        let id = settings.uniqueID
        let delegate = NativeCameraPhotoDelegate { [weak self] result in
          self?.queue.async { [weak self] in
            self?.photos.removeValue(forKey: id)
            continuation.resume(with: result)
          }
        }
        self.photos[id] = delegate
        self.photoOutput.capturePhoto(with: settings, delegate: delegate)
      }
    }
  }

  private func stopOnQueue() {
    if session.isRunning { session.stopRunning() }
    for photo in photos.values { photo.cancel() }
    photos.removeAll()
  }

  private func discover() -> [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                    mediaType: .video, position: .unspecified).devices
      .filter { $0.isConnected }
  }

  private static func describe(_ device: AVCaptureDevice) -> NativeCameraDevice {
    NativeCameraDevice(id: device.uniqueID, name: device.localizedName)
  }

  deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}

/// AVFoundation invokes these callbacks off the main actor. Completion is taken
/// exactly once under a lock; both normal capture and a queued stop can finish it.
private final class NativeCameraPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var completion: (@Sendable (Result<Data, Error>) -> Void)?
  private var data: Data?

  init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) { self.completion = completion }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    if error != nil { finish(.failure(NativeCameraFailure.photo)); return }
    lock.lock()
    data = photo.fileDataRepresentation()
    lock.unlock()
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
    lock.lock()
    let captured = data
    lock.unlock()
    if error == nil, let captured { finish(.success(captured)) }
    else { finish(.failure(NativeCameraFailure.photo)) }
  }

  func cancel() { finish(.failure(CancellationError())) }

  private func finish(_ result: Result<Data, Error>) {
    lock.lock()
    let callback = completion
    completion = nil
    lock.unlock()
    callback?(result)
  }
}
