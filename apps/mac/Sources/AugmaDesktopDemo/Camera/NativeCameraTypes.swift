import AVFoundation
import Foundation

struct NativeCameraDevice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
}

enum NativeCameraAuthorization: Equatable, Sendable {
  case notDetermined, authorized, denied, restricted
}

enum NativeCameraFailure: Error, Equatable, Sendable {
  case denied, restricted, unavailable, configuration, disconnected, interrupted, runtime, photo, save

  var message: String {
    switch self {
    case .denied: String(localized: "摄像头访问已关闭，请在系统设置中允许 Augma 使用摄像头。")
    case .restricted: String(localized: "此 Mac 的摄像头访问受到系统限制。")
    case .unavailable: String(localized: "未找到可用摄像头，请连接摄像头后重试。")
    case .configuration: String(localized: "无法配置此摄像头，请选择其他设备或重试。")
    case .disconnected: String(localized: "摄像头已断开连接，请重新连接或选择其他设备。")
    case .interrupted: String(localized: "摄像头暂时不可用，请关闭占用摄像头的应用后重试。")
    case .runtime: String(localized: "摄像头运行出错，请重试。")
    case .photo: String(localized: "拍照失败，请重试。")
    case .save: String(localized: "无法保存照片，请选择其他位置后重试。")
    }
  }
}

@MainActor
protocol NativeCameraPermissionSource: AnyObject {
  var status: NativeCameraAuthorization { get }
  func request() async -> NativeCameraAuthorization
}

@MainActor
final class NativeCameraPermission: NativeCameraPermissionSource {
  var status: NativeCameraAuthorization {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: .authorized
    case .denied: .denied
    case .restricted: .restricted
    case .notDetermined: .notDetermined
    @unknown default: .restricted
    }
  }

  func request() async -> NativeCameraAuthorization {
    guard status == .notDetermined else { return status }
    _ = await AVCaptureDevice.requestAccess(for: .video)
    return status
  }
}

@MainActor
protocol NativeCameraEngineBackend: AnyObject {
  var previewSession: AVCaptureSession? { get }
  var onDevicesChanged: (@MainActor @Sendable ([NativeCameraDevice]) -> Void)? { get set }
  var onFailure: (@MainActor @Sendable (NativeCameraFailure) -> Void)? { get set }
  func devices() async -> [NativeCameraDevice]
  func start(deviceID: String?) async throws -> NativeCameraDevice
  /// Enqueues a stop immediately, before any subsequently requested start.
  func stop()
  func capturePhoto() async throws -> Data
}
