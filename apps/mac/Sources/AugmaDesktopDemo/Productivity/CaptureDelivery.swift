import Foundation

enum CaptureDestination: String, Codable, CaseIterable, Sendable {
  case appleNotes, microsoftToDo

  var title: String {
    switch self {
    case .appleNotes: String(localized: "macOS 备忘录")
    case .microsoftToDo: "Microsoft To Do"
    }
  }
}

struct CaptureDelivery: Codable, Equatable, Sendable {
  enum Status: String, Codable, Sendable { case pending, sending, failed, uncertain }
  var destination: CaptureDestination
  var status: Status = .pending
  var error: String?
  var listID: String?
  var connectionID: UUID?
}

struct CaptureReceipt: Equatable, Sendable {
  var destination: CaptureDestination
  var remoteID: String
}

enum CaptureError: LocalizedError {
  case message(String)
  case uncertain

  var errorDescription: String? {
    switch self {
    case .message(let message): message
    case .uncertain: String(localized: "发送结果未确认。请先在目标应用中检查，确认未创建后再重试。")
    }
  }
}

@MainActor
protocol CaptureSending {
  func prepare(_ delivery: CaptureDelivery) async throws -> CaptureDelivery
  func send(_ note: QuickNote) async throws -> CaptureReceipt
}
