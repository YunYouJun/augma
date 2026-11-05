import Foundation

enum CodexStorageCategory: String, Codable, Sendable {
  case cache, logs
  var title: String {
    switch self {
    case .cache: String(localized: "Codex 桌面缓存")
    case .logs: String(localized: "Codex 诊断日志")
    }
  }
}

struct CodexStorageScope: Identifiable, Sendable {
  enum Status: Sendable { case complete, partial, missing, unavailable }
  let id: String
  let category: CodexStorageCategory
  let displayPath: String
  var status: Status = .complete
  var bytes: UInt64 = 0
  var fileCount = 0
  var skippedLinks = 0
  var skippedProtected = 0
  var duplicateFiles = 0
  var omittedCandidates = 0
  var issue: String?
  var canAnalyzeWithMole: Bool {
    status == .complete && fileCount > 0 && skippedLinks == 0 && skippedProtected == 0
  }
}

/// A metadata-only preview item, deliberately separate from executable CleanupCandidate.
struct CodexStorageCandidate: Identifiable, Codable, Sendable {
  let id: UUID
  let scopeID: String
  let relativePath: String
  let category: CodexStorageCategory
  let bytes: UInt64
  let modifiedAt: Date
}

struct CodexStorageScan: Sendable {
  let id: UUID
  let checkedAt: Date
  var scopes: [CodexStorageScope]
  var candidates: [CodexStorageCandidate]
  var measuredBytes: UInt64 { scopes.reduce(0) { $0 + $1.bytes } }
  var incomplete: Bool { scopes.contains { $0.status == .partial || $0.status == .unavailable } }
}

/// A short-lived review, bound to the exact items and consumed once by the Codex executor.
struct CodexStoragePreview: Identifiable, Sendable {
  let id = UUID()
  let scanID: UUID
  let createdAt: Date
  let items: [CodexStorageCandidate]
  var bytes: UInt64 { items.reduce(0) { $0 + $1.bytes } }
}

protocol CodexStorageProviding: Sendable {
  func scan() async throws -> CodexStorageScan
  func preview(scanID: UUID, ids: Set<UUID>) async throws -> CodexStoragePreview
  func moleScope(scanID: UUID, scopeID: String) async throws -> URL
  func execute(previewID: UUID, confirmedIDs: Set<UUID>) async throws -> CodexStorageReceipt
  func lastReceipt() async throws -> CodexStorageReceipt?
}

enum CodexStorageError: LocalizedError, Equatable {
  case changed, invalidHome, unavailable, limit, running, busy
  var errorDescription: String? {
    switch self {
    case .running: String(localized: "请先退出 Codex 桌面应用和 CLI，再重新扫描并确认清理。")
    case .busy: String(localized: "Codex 清理正在执行，请等待结果回执。")
    case .changed: String(localized: "Codex 扫描已过期或文件发生变化，请重新扫描。")
    case .invalidHome: String(localized: "CODEX_HOME 必须是明确的绝对目录，且不能指向受保护的数据范围。")
    case .unavailable: String(localized: "Codex 路径不可读取或包含符号链接，已跳过此范围。")
    case .limit: String(localized: "达到扫描预算，未完整统计；此范围不生成清理候选。")
    }
  }
}

struct CodexStorageReceipt: Identifiable, Codable, Sendable {
  enum Status: String, Codable, Sendable {
    case trashed, skipped, failed, uncertain
    var title: String {
      switch self {
      case .trashed: String(localized: "已移入废纸篓")
      case .skipped: String(localized: "已跳过")
      case .failed: String(localized: "执行失败")
      case .uncertain: String(localized: "状态待核实")
      }
    }
  }
  struct Item: Identifiable, Codable, Sendable {
    let candidate: CodexStorageCandidate
    let displayPath: String
    var status: Status = .skipped
    var detail: String = String(localized: "未执行")
    var id: UUID { candidate.id }
  }
  let id: UUID
  let startedAt: Date
  var finishedAt: Date?
  var items: [Item]
  var warning: String?
  var trashedBytes: UInt64 {
    items.filter { $0.status == .trashed }.reduce(0) { $0 + $1.candidate.bytes }
  }
}
