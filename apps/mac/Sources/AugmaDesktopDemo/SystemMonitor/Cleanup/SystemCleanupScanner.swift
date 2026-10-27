import CryptoKit
import Foundation

enum CleanupCategory: String, CaseIterable, Sendable {
  case installers, xcode

  var title: String {
    switch self {
    case .installers: String(localized: "旧安装包")
    case .xcode: String(localized: "Xcode 构建缓存")
    }
  }
}

struct CleanupCandidate: Identifiable, Sendable {
  let id: UUID
  let url: URL
  let category: CleanupCategory
  let bytes: UInt64
  let fingerprint: String
}

struct CleanupScan: Sendable {
  var candidates: [CleanupCandidate]
  var incomplete = false
}

struct CleanupOutcome: Sendable {
  var moved: Set<UUID> = []
  var failures: [String] = []
}

/// On-demand, bounded metadata reads. Only candidates issued by this scanner can be trashed.
actor SystemCleanupScanner {
  typealias Trash = @Sendable (URL) throws -> Void
  private let home: URL
  private let trash: Trash
  private let maximumEntries: Int
  private let maximumDuration: TimeInterval
  private let now: @Sendable () -> Date
  private var catalog: [UUID: CleanupCandidate] = [:]
  private let files = FileManager.default

  init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
       maximumEntries: Int = 50_000, maximumDuration: TimeInterval = 8,
       now: @escaping @Sendable () -> Date = { .now },
       trash: @escaping Trash = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) {
    self.home = home.standardizedFileURL.resolvingSymlinksInPath()
    self.maximumEntries = maximumEntries
    self.maximumDuration = maximumDuration
    self.now = now
    self.trash = trash
  }

  func scan() throws -> CleanupScan {
    catalog = [:]
    var result = CleanupScan(candidates: [])
    var budget = Budget(remaining: maximumEntries, deadline: .now.advanced(by: .seconds(maximumDuration)))
    for category in CleanupCategory.allCases {
      let root = root(for: category)
      guard files.fileExists(atPath: root.path) else { continue }
      do {
        try checkLocation(root)
        var unreadable = false
        guard let items = files.enumerator(at: root, includingPropertiesForKeys: nil,
          options: [.skipsSubdirectoryDescendants], errorHandler: { _, _ in unreadable = true; return false }) else { throw Failure.unreadable }
        for case let url as URL in items {
          try budget.consume()
          guard accepts(url, category: category) else { continue }
          do {
            let measurement = try measure(url, budget: &budget)
            guard measurement.latest < now().addingTimeInterval(-7 * 86_400), measurement.bytes > 0 else { continue }
            let candidate = CleanupCandidate(id: UUID(), url: url, category: category,
                                             bytes: measurement.bytes, fingerprint: measurement.fingerprint)
            result.candidates.append(candidate)
            if result.candidates.count >= 100 { throw Failure.limit }
          } catch is CancellationError { throw CancellationError() }
          catch Failure.limit { throw Failure.limit }
          catch { result.incomplete = true }
        }
        // FileManager enumerators can stop on an access error without throwing.
        if unreadable { result.incomplete = true }
      } catch is CancellationError { throw CancellationError() }
      catch Failure.limit { result.incomplete = true; break }
      catch { result.incomplete = true }
    }
    result.candidates.sort { $0.bytes > $1.bytes }
    catalog = Dictionary(uniqueKeysWithValues: result.candidates.map { ($0.id, $0) })
    return result
  }

  func moveToTrash(ids: Set<UUID>) -> CleanupOutcome {
    var outcome = CleanupOutcome()
    var budget = Budget(remaining: maximumEntries, deadline: .now.advanced(by: .seconds(maximumDuration)))
    for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let candidate = catalog[id] else {
        outcome.failures.append(String(localized: "清理项已失效，请重新扫描。"))
        continue
      }
      do {
        let root = root(for: candidate.category)
        try checkLocation(root)
        guard candidate.url.deletingLastPathComponent().standardizedFileURL.path == root.path,
          accepts(candidate.url, category: candidate.category) else { throw Failure.changed }
        let measurement = try measure(candidate.url, budget: &budget)
        guard measurement.fingerprint == candidate.fingerprint,
          measurement.latest < now().addingTimeInterval(-7 * 86_400) else { throw Failure.changed }
        try trash(candidate.url)
        outcome.moved.insert(id)
        catalog[id] = nil
      } catch {
        outcome.failures.append(candidate.url.lastPathComponent + ": " + error.localizedDescription)
      }
    }
    return outcome
  }

  private func root(for category: CleanupCategory) -> URL {
    home.appendingPathComponent(category == .installers ? "Downloads" : "Library/Developer/Xcode/DerivedData")
  }

  private func accepts(_ url: URL, category: CleanupCategory) -> Bool {
    guard let attributes = try? files.attributesOfItem(atPath: url.path),
      let type = attributes[.type] as? FileAttributeType else { return false }
    switch category {
    case .installers: return type == .typeRegular && ["dmg", "pkg", "xip"].contains(url.pathExtension.lowercased())
    case .xcode: return type == .typeDirectory
    }
  }

  private func checkLocation(_ url: URL) throws {
    guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().path,
      url.standardizedFileURL.path.hasPrefix(home.path + "/") else { throw Failure.changed }
  }

  private struct Measurement {
    var bytes: UInt64 = 0
    var latest = Date.distantPast
    var fingerprint = ""
  }

  private func measure(_ url: URL, budget: inout Budget) throws -> Measurement {
    try checkLocation(url)
    var result = Measurement()
    var records: [String] = []
    let volume = try files.attributesOfItem(atPath: url.path)[.systemNumber] as? NSNumber
    func read(_ entry: URL) throws {
      try budget.consume()
      let attributes = try files.attributesOfItem(atPath: entry.path)
      guard let type = attributes[.type] as? FileAttributeType,
        let date = attributes[.modificationDate] as? Date,
        attributes[.systemNumber] as? NSNumber == volume,
        type == .typeRegular || type == .typeDirectory || type == .typeSymbolicLink else { throw Failure.unreadable }
      // Modification, identity, size and topology are rechecked before moving a directory.
      let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
      let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
      let created = attributes[.creationDate] as? Date ?? date
      let destination = type == .typeSymbolicLink ? try files.destinationOfSymbolicLink(atPath: entry.path) : ""
      records.append("\(entry.path)\u{0}\(type.rawValue)\u{0}\(inode)\u{0}\(size)\u{0}\(date.timeIntervalSince1970)\u{0}\(created.timeIntervalSince1970)\u{0}\(destination)")
      result.latest = max(result.latest, date, created)
      if type == .typeRegular {
        let values = try entry.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        let bytes = UInt64(max(0, values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? Int(size)))
        result.bytes += bytes
      }
    }
    try read(url)
    if (try files.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeDirectory {
      var unreadable = false
      guard let enumerator = files.enumerator(at: url, includingPropertiesForKeys: nil, options: [],
        errorHandler: { _, _ in unreadable = true; return false }) else { throw Failure.unreadable }
      for case let entry as URL in enumerator {
        // FileManager does not descend into symbolic links. Record the link itself,
        // never its destination; reject other filesystems in read().
        try read(entry)
      }
      guard !unreadable else { throw Failure.unreadable }
    }
    try checkLocation(url)
    var hash = SHA256()
    for record in records.sorted() { hash.update(data: Data((record + "\n").utf8)) }
    result.fingerprint = hash.finalize().map { String(format: "%02x", $0) }.joined()
    return result
  }

  private struct Budget {
    var remaining: Int
    let deadline: ContinuousClock.Instant
    mutating func consume() throws {
      try Task.checkCancellation()
      guard remaining > 0, ContinuousClock.now < deadline else { throw Failure.limit }
      remaining -= 1
    }
  }

  private enum Failure: LocalizedError {
    case changed, unreadable, limit
    var errorDescription: String? {
      switch self {
      case .changed: String(localized: "文件已变化或路径不安全，请重新扫描。")
      case .unreadable: String(localized: "无法完整读取，已跳过此项。")
      case .limit: String(localized: "已达到扫描上限，请稍后重新扫描。")
      }
    }
  }
}
