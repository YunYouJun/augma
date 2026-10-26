import Foundation

struct NetworkHistoryPoint: Sendable {
  var date: Date
  var received: Double
  var sent: Double
}

struct NetworkHistory: Sendable {
  static let capacity = 120
  static let duration: TimeInterval = 120
  private(set) var points: [NetworkHistoryPoint] = []
  private(set) var interface: String?

  mutating func append(_ usage: NetworkUsage?, at date: Date) {
    guard let usage, usage.receivedPerSecond.isFinite, usage.sentPerSecond.isFinite,
      usage.receivedPerSecond >= 0, usage.sentPerSecond >= 0
    else { clear(); return }
    if interface != usage.interface || points.last.map({ date <= $0.date }) == true { clear() }
    interface = usage.interface
    points.removeAll { date.timeIntervalSince($0.date) > Self.duration }
    points.append(NetworkHistoryPoint(date: date, received: usage.receivedPerSecond, sent: usage.sentPerSecond))
    if points.count > Self.capacity { points.removeFirst(points.count - Self.capacity) }
  }

  mutating func clear() {
    points = []
    interface = nil
  }
}
