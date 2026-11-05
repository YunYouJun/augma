import Foundation

enum DiskUsageMetric: String, CaseIterable {
  case allocated, logical

  var title: String {
    switch self {
    case .allocated: String(localized: "磁盘分配")
    case .logical: String(localized: "逻辑大小")
    }
  }
}

struct DiskUsageNode: Identifiable, Equatable, Sendable {
  let url: URL
  let isDirectory: Bool
  var logicalBytes: UInt64 = 0
  var allocatedBytes: UInt64 = 0
  var fileCount = 0
  var incomplete = false
  var children: [DiskUsageNode] = []
  var id: String { url.path }

  func bytes(_ metric: DiskUsageMetric) -> UInt64 {
    metric == .allocated ? allocatedBytes : logicalBytes
  }

  func find(_ path: String) -> Self? {
    if id == path { return self }
    for child in children where child.isDirectory {
      if let found = child.find(path) { return found }
    }
    return nil
  }

  func largestDirectories(metric: DiskUsageMetric, limit: Int = 20) -> [Self] {
    var result: [Self] = []
    func visit(_ node: Self) {
      for child in node.children where child.isDirectory {
        result.append(child)
        visit(child)
      }
    }
    visit(self)
    return Array(result.sorted {
      $0.bytes(metric) == $1.bytes(metric) ? $0.id < $1.id : $0.bytes(metric) > $1.bytes(metric)
    }.prefix(limit))
  }
}

struct DiskUsageIssue: Identifiable, Equatable, Sendable {
  enum Reason: Sendable {
    case unreadable, changed, differentVolume, entryLimit, timeLimit, depthLimit

    var title: String {
      switch self {
      case .unreadable: String(localized: "无法读取")
      case .changed: String(localized: "扫描期间发生变化")
      case .differentVolume: String(localized: "已跳过其他磁盘卷")
      case .entryLimit: String(localized: "已达到条目上限")
      case .timeLimit: String(localized: "已达到时间上限")
      case .depthLimit: String(localized: "已达到目录深度上限")
      }
    }
  }
  let path: String
  let reason: Reason
  var id: String { path + String(describing: reason) }
}

struct DiskUsageProgress: Sendable {
  var entries = 0
  var logicalBytes: UInt64 = 0
}

struct DiskUsageSnapshot: Equatable, Sendable {
  let root: DiskUsageNode
  let checkedAt: Date
  let entries: Int
  let skippedSymlinks: Int
  let duplicateFiles: Int
  let skippedSpecialFiles: Int
  let issues: [DiskUsageIssue]
  let omittedIssues: Int
}

protocol DiskUsageScanning: Sendable {
  func scan(_ root: URL, progress: @escaping @Sendable (DiskUsageProgress) -> Void) async throws -> DiskUsageSnapshot
}

enum DiskUsageError: LocalizedError {
  case invalidRoot, unreadable
  var errorDescription: String? {
    switch self {
    case .invalidRoot: String(localized: "请选择可直接访问的文件夹，符号链接不能作为扫描范围。")
    case .unreadable: String(localized: "无法读取所选文件夹，请检查访问权限或重新选择。")
    }
  }
}
