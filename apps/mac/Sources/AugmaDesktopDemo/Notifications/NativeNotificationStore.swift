import Combine
import Foundation

struct NativeNotice: Identifiable, Equatable {
  let id: UUID
  let date: Date
  let title: String
  let detail: String
  let symbol: String
  var read: Bool
}

/// App activity for this window's session, shared by its main and immersive UI.
/// This does not read Notification Center or publish system notifications.
@MainActor
final class NativeNotificationStore: ObservableObject {
  @Published private(set) var notices: [NativeNotice] = []
  var unreadCount: Int { notices.lazy.filter { !$0.read }.count }

  private let capacity: Int
  private let now: () -> Date

  init(capacity: Int = 100, now: @escaping () -> Date = Date.init) {
    self.capacity = min(1_000, max(1, capacity))
    self.now = now
  }

  func post(title: String, detail: String, symbol: String = "bell") {
    let notice = NativeNotice(id: UUID(), date: now(), title: title, detail: detail, symbol: symbol, read: false)
    notices = Array(([notice] + notices).prefix(capacity))
  }

  func markAllRead() {
    guard unreadCount > 0 else { return }
    notices = notices.map { notice in
      var copy = notice
      copy.read = true
      return copy
    }
  }

  func clear() { notices.removeAll() }
}
