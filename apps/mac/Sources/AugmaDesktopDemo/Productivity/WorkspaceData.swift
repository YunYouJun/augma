import Foundation

struct QuickNote: Codable, Identifiable, Equatable, Sendable {
  var id = UUID()
  var text: String
  var createdAt: Date
  var updatedAt: Date
  // nil identifies a pre-integration local note. Never send migrated notes automatically.
  var delivery: CaptureDelivery?
  var title: String { String(text.split(separator: "\n").first ?? "").prefix(80).description }
}

struct FocusSession: Codable, Identifiable, Equatable, Sendable {
  enum Status: String, Codable, Sendable { case running, paused, completed }
  var id = UUID()
  var startedAt: Date
  var duration: TimeInterval
  var remaining: TimeInterval
  var deadline: Date?
  var status: Status

  func secondsRemaining(at date: Date) -> TimeInterval {
    status == .running ? max(0, deadline?.timeIntervalSince(date) ?? 0) : status == .paused ? remaining : 0
  }
}

struct FocusCompletion: Codable, Identifiable, Equatable, Sendable {
  let id: UUID
  let duration: TimeInterval
  let completedAt: Date
}

struct WorkspaceData: Codable, Equatable, Sendable {
  var version = 2
  var notes: [QuickNote] = []
  var noteDraft = ""
  var captureDestination: CaptureDestination?
  var focus: FocusSession?
  var completions: [FocusCompletion] = []
  var recentActions: [String] = []

  func validate() throws {
    guard (1...2).contains(version), Set(notes.map(\.id)).count == notes.count,
          notes.allSatisfy({ $0.createdAt.timeIntervalSince1970.isFinite && $0.updatedAt.timeIntervalSince1970.isFinite }),
          completions.allSatisfy({ $0.duration.isFinite && $0.duration > 0 && $0.completedAt.timeIntervalSince1970.isFinite }) else {
      throw WorkspaceFileError.invalidData
    }
    if let focus {
      guard focus.duration.isFinite, focus.remaining.isFinite,
            focus.duration > 0, focus.duration <= 86_400, focus.remaining >= 0, focus.remaining <= focus.duration,
            focus.startedAt.timeIntervalSince1970.isFinite,
            focus.deadline?.timeIntervalSince1970.isFinite != false,
            focus.status != .running || focus.deadline != nil else { throw WorkspaceFileError.invalidData }
    }
  }
}

enum WorkspaceFileError: LocalizedError {
  case invalidData
  var errorDescription: String? { String(localized: "本地数据格式无法识别，原文件已保留。") }
}

enum FocusTime {
  static func label(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
      : String(format: "%02d:%02d", value / 60, value % 60)
  }
}
