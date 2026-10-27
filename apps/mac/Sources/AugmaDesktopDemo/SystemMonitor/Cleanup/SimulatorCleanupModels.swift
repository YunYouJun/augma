import Foundation

enum SimulatorCleanupKind: String, Sendable {
  case device, runtime
}

struct SimulatorCleanupItem: Identifiable, Equatable, Sendable {
  let kind: SimulatorCleanupKind
  let identifier: String
  let name: String
  let runtimeIdentifier: String
  let version: String?
  let build: String?
  let state: String
  let bytes: UInt64?
  let lastUsedAt: Date?
  let isAvailable: Bool?
  let dependentDeviceCount: Int
  let restriction: String?
  var deviceTypeIdentifier: String? = nil
  var modelIdentifier: String? = nil

  var id: String { kind.rawValue + ":" + identifier }
  var canDelete: Bool { restriction == nil }
}

struct SimulatorCleanupScan: Identifiable, Sendable {
  let id: UUID
  let createdAt: Date
  let items: [SimulatorCleanupItem]
  let warnings: [String]

  init(id: UUID = UUID(), createdAt: Date = .now, items: [SimulatorCleanupItem], warnings: [String] = []) {
    self.id = id
    self.createdAt = createdAt
    self.items = items
    self.warnings = warnings
  }

  var incomplete: Bool { !warnings.isEmpty }
  var deviceBytes: UInt64 { totalBytes(kind: .device) }
  var runtimeBytes: UInt64 { totalBytes(kind: .runtime) }

  private func totalBytes(kind: SimulatorCleanupKind) -> UInt64 {
    items.filter { $0.kind == kind }.reduce(0) { total, item in
      let (sum, overflow) = total.addingReportingOverflow(item.bytes ?? 0)
      return overflow ? .max : sum
    }
  }
}

enum SimulatorCleanupStatus: String, Sendable {
  case deleted, skipped, failed, pending
}

struct SimulatorCleanupResult: Identifiable, Sendable {
  let item: SimulatorCleanupItem
  let status: SimulatorCleanupStatus
  let message: String
  var id: String { item.id }
}

struct SimulatorCleanupReceipt: Sendable {
  let results: [SimulatorCleanupResult]
  let availableSpaceChange: Int64?
  let createdAt: Date
}

protocol SimulatorCleanupProviding: Sendable {
  func scan() async throws -> SimulatorCleanupScan
  func delete(scanID: UUID, ids: Set<String>, runtimeScopeAcknowledged: Bool) async throws -> SimulatorCleanupReceipt
}

extension SimulatorCleanupProviding {
  func delete(scanID: UUID, ids: Set<String>) async throws -> SimulatorCleanupReceipt {
    try await delete(scanID: scanID, ids: ids, runtimeScopeAcknowledged: false)
  }
}
