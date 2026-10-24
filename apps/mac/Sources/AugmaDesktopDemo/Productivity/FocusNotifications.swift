import AppKit
import UserNotifications

@MainActor
final class FocusNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
  @Published private(set) var allowed = false
  @Published private(set) var message: String?
  var onOpen: (() -> Void)?
  private let enabled: Bool
  private var desired: FocusSession?
  private var revision = 0
  private var worker: Task<Void, Never>?
  private let identifier = "augma.focus.completed"
  private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

  init(enabled: Bool = true) { self.enabled = enabled }

  func activate() {
    guard enabled else { return }
    center.delegate = self
    Task { await refreshPermission() }
  }

  func requestPermission() async {
    guard enabled else { return }
    do {
      _ = try await center.requestAuthorization(options: [.alert, .sound])
      await refreshPermission()
      if !allowed { message = String(localized: "通知未开启。可在系统设置中允许 Augma 通知，计时仍会继续。") }
      sync(desired)
    } catch { message = String(localized: "无法开启通知，请在系统设置中检查 Augma 的通知权限。") }
  }

  func refreshPermission() async {
    guard enabled else { return }
    let settings = await center.notificationSettings()
    allowed = [.authorized, .provisional].contains(settings.authorizationStatus)
  }

  func sync(_ session: FocusSession?) {
    guard enabled else { return }
    desired = session
    revision += 1
    guard worker == nil else { return }
    worker = Task { [weak self] in
      guard let self else { return }
      while true {
        let revision = self.revision
        let session = self.desired
        if session?.status != .completed {
          self.center.removePendingNotificationRequests(withIdentifiers: [self.identifier])
          if let session, session.status == .running, let deadline = session.deadline, deadline > .now {
            await self.refreshPermission()
            if self.allowed, revision == self.revision {
              let content = UNMutableNotificationContent()
              content.title = String(localized: "专注完成")
              content.body = String(localized: "这一段专注时间结束了，休息一下吧。")
              content.sound = .default
              let request = UNNotificationRequest(identifier: self.identifier, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false))
              do { try await self.center.add(request); self.message = nil }
              catch { self.message = String(localized: "到时通知未能安排，计时仍会继续。") }
            }
          }
        }
        // Serialize asynchronous updates: a late start must not replace a newer pause/cancel.
        if revision == self.revision { break }
      }
      self.worker = nil
    }
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse) async {
    await MainActor.run { self.onOpen?() }
  }
}
