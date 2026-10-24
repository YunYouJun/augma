import Combine
import Foundation

enum NativeDeviceConnection: String, Equatable, Sendable {
  case connected, connecting, disconnected, sleeping

  var title: String {
    switch self {
    case .connected: String(localized: "模拟设备已连接")
    case .connecting: String(localized: "正在建立模拟连接…")
    case .disconnected: String(localized: "模拟设备已断开")
    case .sleeping: String(localized: "模拟设备正在待机")
    }
  }
}

/// Connection is an explicit device simulation. Native app features do not
/// require an external headset or network connection to remain accessible.
@MainActor
final class NativeDeviceStore: ObservableObject {
  @Published private(set) var connection: NativeDeviceConnection = .connected
  var online: Bool { connection == .connected }
  var onSuspend: (() -> Void)?

  private let notifications: NativeNotificationStore
  private let uptime: () -> TimeInterval
  private let autoTick: Bool
  private var startedAt: TimeInterval?
  private var generation: UInt64 = 0
  private var connectTask: Task<Void, Never>?
  private var terminated = false

  init(notifications: NativeNotificationStore,
       uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       autoTick: Bool = true) {
    self.notifications = notifications
    self.uptime = uptime
    self.autoTick = autoTick
  }

  func connect() {
    guard !terminated, connection != .connected, connection != .connecting else { return }
    let now = uptime()
    guard now.isFinite else { return }
    cancelConnection()
    startedAt = now
    connection = .connecting
    guard autoTick else { return }
    let request = generation
    connectTask = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        guard let self, !Task.isCancelled, request == self.generation else { return }
        self.refreshConnection()
        if self.connection != .connecting { return }
      }
    }
  }

  /// Monotonic clock injection keeps cancellation and reconnect tests deterministic.
  func refreshConnection() {
    guard !terminated, connection == .connecting, let startedAt else { return }
    let now = uptime()
    guard now.isFinite, now - startedAt >= 0.9 else { return }
    cancelConnection()
    connection = .connected
    notifications.post(title: String(localized: "模拟设备已连接"),
                       detail: String(localized: "模拟连接已就绪，可以继续浏览空间和使用应用。"),
                       symbol: "checkmark.circle")
  }

  func sleep() { suspend(.sleeping) }
  func disconnect() { suspend(.disconnected) }

  private func suspend(_ next: NativeDeviceConnection) {
    guard !terminated, connection != next else { return }
    cancelConnection()
    connection = next
    onSuspend?()
    notifications.post(title: next.title,
                       detail: String(localized: "已停止本窗口的模拟扫描、路线和语音助手。其他原生功能仍可使用。"),
                       symbol: next == .sleeping ? "moon" : "link")
  }

  func shutdown() {
    guard !terminated else { return }
    terminated = true
    cancelConnection()
    onSuspend = nil
  }

  private func cancelConnection() {
    generation &+= 1
    connectTask?.cancel()
    connectTask = nil
    startedAt = nil
  }

  deinit { connectTask?.cancel() }
}
