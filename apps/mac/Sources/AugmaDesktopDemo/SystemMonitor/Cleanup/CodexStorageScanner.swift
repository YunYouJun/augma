import Foundation

/// On-demand metadata inspection of fixed cache/log roots. Only reviewed, unchanged files can be moved to Trash; protected data is never offered.
actor CodexStorageScanner: CodexStorageProviding {
  private struct Rule: Sendable {
    let id: String
    let category: CodexStorageCategory
    let url: URL
  }
  private struct Identity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let bytes: UInt64
    let modified: Date
    let created: Date
    let links: UInt64
    var key: String { "\(device):\(inode)" }
  }
  private struct Record: Sendable {
    let candidate: CodexStorageCandidate
    let url: URL
    let identity: Identity
  }
  private struct Budget {
    var remaining: Int
    let deadline: ContinuousClock.Instant
    mutating func consume() throws {
      try Task.checkCancellation()
      guard remaining > 0, .now < deadline else { throw CodexStorageError.limit }
      remaining -= 1
    }
  }
  private let files = FileManager.default
  private let home: URL
  private let codexHome: URL
  private let homeIsValid: Bool
  private let maximumEntries: Int
  private let maximumDuration: TimeInterval
  private let maximumDepth: Int
  private let now: @Sendable () -> Date
  private let trash: @Sendable (URL) throws -> Void
  private let ensureStopped: @Sendable () async throws -> Void
  private let journal: CodexStorageJournal
  private var executing = false
  private var prepared: CodexStoragePreview?
  private var latest: CodexStorageScan?
  private var records: [UUID: Record] = [:]
  private var roots: [String: Identity] = [:]
  private static let protectedNames: Set<String> = [
    "sessions", "archived_sessions", "artifacts", "archives", "visualizations", "generated_images",
    "outputs",
    "worktrees", "backups", "skills", "plugins", "memories", "auth.json", "config.toml",
    "history.jsonl",
    "cookies", "history", "login data", "local storage", "indexeddb", "session storage",
    "preferences",
  ]

  init(
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    codexHome: URL? = nil,
    environmentHome: String? = ProcessInfo.processInfo.environment["CODEX_HOME"],
    maximumEntries: Int = 5_000, maximumDuration: TimeInterval = 0.8, maximumDepth: Int = 24,
    now: @escaping @Sendable () -> Date = { .now },
    trash: @escaping @Sendable (URL) throws -> Void = { url in
      try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    },
    ensureStopped: @escaping @Sendable () async throws -> Void = {
      try await CodexStorageActivity.ensureStopped()
    },
    receiptURL: URL? = nil
  ) {
    let canonicalHome = home.standardizedFileURL.resolvingSymlinksInPath()
    self.home = canonicalHome
    self.codexHome =
      codexHome ?? environmentHome.map { URL(filePath: $0) }
      ?? canonicalHome.appendingPathComponent(".codex")
    self.homeIsValid =
      codexHome != nil || environmentHome == nil || environmentHome?.hasPrefix("/") == true
    self.maximumEntries = maximumEntries
    self.maximumDuration = maximumDuration
    self.maximumDepth = maximumDepth
    self.now = now
    self.trash = trash
    self.ensureStopped = ensureStopped
    self.journal = CodexStorageJournal(
      url: receiptURL
        ?? canonicalHome.appendingPathComponent(
          "Library/Application Support/Augma/Cleanup/codex-last-receipt.json"))
  }

  private func rules() throws -> [Rule] {
    let root = codexHome.standardizedFileURL
    guard homeIsValid, codexHome.path.hasPrefix("/"), root.path != "/",
      !root.pathComponents.contains(where: { Self.protectedNames.contains($0.lowercased()) })
    else {
      throw CodexStorageError.invalidHome
    }
    // Each entry is a fixed leaf, never an entire Chromium profile or CODEX_HOME.
    let cachePaths = [
      "Library/Caches/Codex/Default/Cache", "Library/Caches/Codex/Default/Code Cache",
      "Library/Application Support/Codex/Default/Cache",
      "Library/Application Support/Codex/Default/Code Cache",
      "Library/Application Support/Codex/Default/GPUCache",
      "Library/Application Support/Codex/Cache",
      "Library/Application Support/Codex/Code Cache", "Library/Application Support/Codex/GPUCache",
    ]
    var result = cachePaths.enumerated().map { index, path in
      Rule(id: "cache-\(index)", category: .cache, url: home.appendingPathComponent(path))
    }
    result += [
      Rule(id: "cli-log", category: .logs, url: root.appendingPathComponent("log")),
      Rule(id: "cli-logs", category: .logs, url: root.appendingPathComponent("logs")),
    ]
    // Misconfigured roots must not cause overlapping attribution or widened scans.
    for (index, rule) in result.enumerated() {
      guard
        !result.prefix(index).contains(where: {
          rule.url.path == $0.url.path || rule.url.path.hasPrefix($0.url.path + "/")
            || $0.url.path.hasPrefix(rule.url.path + "/")
        })
      else { throw CodexStorageError.invalidHome }
    }
    return result
  }

  func scan() throws -> CodexStorageScan {
    guard !executing else { throw CodexStorageError.busy }
    prepared = nil
    latest = nil
    records = [:]
    roots = [:]
    var scan = CodexStorageScan(id: UUID(), checkedAt: now(), scopes: [], candidates: [])
    var seen: Set<String> = []
    for rule in try rules() {
      try Task.checkCancellation()
      var scope = CodexStorageScope(
        id: rule.id, category: rule.category, displayPath: displayPath(rule.url))
      var candidates: [Record] = []
      var budget = Budget(
        remaining: maximumEntries, deadline: .now.advanced(by: .seconds(maximumDuration)))
      do {
        try checkCanonical(rule.url)
        // attributesOfItem distinguishes a missing leaf from an unreadable/symlinked root.
        let attributes: [FileAttributeKey: Any]
        do { attributes = try files.attributesOfItem(atPath: rule.url.path) } catch let error
          as CocoaError where error.code == .fileReadNoSuchFile
        {
          scope.status = .missing
          scan.scopes.append(scope)
          continue
        }
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
          throw CodexStorageError.unavailable
        }
        let rootIdentity = try identity(attributes)
        roots[rule.id] = rootIdentity
        var enumerationFailed = false
        guard
          let enumerator = files.enumerator(
            at: rule.url, includingPropertiesForKeys: nil, options: [],
            errorHandler: { _, _ in
              enumerationFailed = true
              return false
            })
        else { throw CodexStorageError.unavailable }
        for case let url as URL in enumerator {
          try budget.consume()
          if Self.isProtected(url.lastPathComponent) {
            enumerator.skipDescendants()
            scope.skippedProtected += 1
            continue
          }
          let attributes = try files.attributesOfItem(atPath: url.path)
          let type = attributes[.type] as? FileAttributeType
          if type == .typeSymbolicLink {
            enumerator.skipDescendants()
            scope.skippedLinks += 1
            continue
          }
          try checkCanonical(url)
          let metadata = try identity(attributes)
          guard metadata.device == rootIdentity.device else { throw CodexStorageError.unavailable }
          if type == .typeDirectory {
            if enumerator.level >= maximumDepth { throw CodexStorageError.limit }
            continue
          }
          guard type == .typeRegular else { throw CodexStorageError.unavailable }
          guard seen.insert(metadata.key).inserted else {
            scope.duplicateFiles += 1
            continue
          }
          let (sum, overflow) = scope.bytes.addingReportingOverflow(metadata.bytes)
          guard !overflow else { throw CodexStorageError.unavailable }
          scope.bytes = sum
          scope.fileCount += 1
          // Foundation can spell the same macOS temp root as /var and /private/var.
          let relativePath = url.pathComponents.suffix(enumerator.level).joined(separator: "/")
          // Even a cache path does not imply a hard-linked, recent or unknown log file is disposable.
          guard metadata.bytes > 0, metadata.links == 1,
            max(metadata.modified, metadata.created) < now().addingTimeInterval(-7 * 86_400),
            rule.category == .cache || Self.isDiagnosticLog(url.lastPathComponent)
          else { continue }
          candidates.append(
            Record(
              candidate: .init(
                id: UUID(), scopeID: rule.id, relativePath: relativePath,
                category: rule.category, bytes: metadata.bytes, modifiedAt: metadata.modified),
              url: url, identity: metadata))
        }
        guard !enumerationFailed else { throw CodexStorageError.unavailable }
        try checkCanonical(rule.url)
        let currentRoot = try identity(files.attributesOfItem(atPath: rule.url.path))
        guard currentRoot.device == rootIdentity.device, currentRoot.inode == rootIdentity.inode
        else { throw CodexStorageError.changed }
        candidates.sort { $0.candidate.bytes > $1.candidate.bytes }
        scope.omittedCandidates = max(0, candidates.count - 100)
        for record in candidates.prefix(100) {
          records[record.candidate.id] = record
          scan.candidates.append(record.candidate)
        }
      } catch is CancellationError { throw CancellationError() } catch {
        scope.status = scope.fileCount > 0 ? .partial : .unavailable
        scope.issue = error.localizedDescription
        roots[rule.id] = nil
      }
      scan.scopes.append(scope)
    }
    try Task.checkCancellation()
    scan.candidates.sort { $0.bytes > $1.bytes }
    latest = scan
    return scan
  }

  func preview(scanID: UUID, ids: Set<UUID>) throws -> CodexStoragePreview {
    guard !executing else { throw CodexStorageError.busy }
    prepared = nil
    guard let latest, latest.id == scanID, !ids.isEmpty,
      now().timeIntervalSince(latest.checkedAt) >= 0,
      now().timeIntervalSince(latest.checkedAt) <= 300,
      ids.isSubset(of: Set(latest.candidates.map(\.id)))
    else { throw CodexStorageError.changed }
    for id in ids {
      try Task.checkCancellation()
      guard let record = records[id],
        let rule = try rules().first(where: { $0.id == record.candidate.scopeID })
      else {
        throw CodexStorageError.changed
      }
      try validateRoot(rule)
      try checkCanonical(record.url)
      let attributes = try files.attributesOfItem(atPath: record.url.path)
      guard attributes[.type] as? FileAttributeType == .typeRegular,
        try identity(attributes) == record.identity
      else { throw CodexStorageError.changed }
    }
    let result = CodexStoragePreview(
      scanID: scanID, createdAt: now(), items: latest.candidates.filter { ids.contains($0.id) })
    prepared = result
    return result
  }

  func moleScope(scanID: UUID, scopeID: String) throws -> URL {
    guard !executing else { throw CodexStorageError.busy }
    guard let latest, latest.id == scanID, now().timeIntervalSince(latest.checkedAt) >= 0,
      now().timeIntervalSince(latest.checkedAt) <= 300,
      latest.scopes.contains(where: { $0.id == scopeID && $0.canAnalyzeWithMole }),
      let rule = try rules().first(where: { $0.id == scopeID })
    else { throw CodexStorageError.changed }
    try Task.checkCancellation()
    try validateRoot(rule)
    // Recheck exclusions immediately before invoking an optional analyzer; never hand it a profile root.
    var budget = Budget(
      remaining: maximumEntries, deadline: .now.advanced(by: .seconds(maximumDuration)))
    var failed = false
    guard
      let enumerator = files.enumerator(
        at: rule.url, includingPropertiesForKeys: nil, options: [],
        errorHandler: { _, _ in
          failed = true
          return false
        })
    else { throw CodexStorageError.unavailable }
    for case let url as URL in enumerator {
      try budget.consume()
      guard !Self.isProtected(url.lastPathComponent),
        enumerator.level <= maximumDepth
      else { throw CodexStorageError.unavailable }
      try checkCanonical(url)
      let attributes = try files.attributesOfItem(atPath: url.path)
      guard
        attributes[.type] as? FileAttributeType == .typeDirectory
          || attributes[.type] as? FileAttributeType == .typeRegular,
        try identity(attributes).device == roots[rule.id]?.device
      else { throw CodexStorageError.unavailable }
    }
    guard !failed else { throw CodexStorageError.unavailable }
    try validateRoot(rule)
    return rule.url
  }

  /// Confirmation is exact, short-lived and one-use. A scan never authorizes execution.
  func execute(previewID: UUID, confirmedIDs: Set<UUID>) async throws -> CodexStorageReceipt {
    guard !executing else { throw CodexStorageError.busy }
    guard let review = prepared, review.id == previewID, latest?.id == review.scanID,
      !confirmedIDs.isEmpty, confirmedIDs == Set(review.items.map(\.id)),
      now().timeIntervalSince(review.createdAt) >= 0,
      now().timeIntervalSince(review.createdAt) <= 300,
      let latest, now().timeIntervalSince(latest.checkedAt) >= 0,
      now().timeIntervalSince(latest.checkedAt) <= 300
    else { throw CodexStorageError.changed }
    prepared = nil
    executing = true
    defer {
      executing = false
      self.latest = nil
      records = [:]
      roots = [:]
    }
    var receipt = CodexStorageReceipt(
      id: review.id, startedAt: now(),
      items: review.items.map { item in
        .init(
          candidate: item,
          displayPath: (latest.scopes.first { $0.id == item.scopeID }?.displayPath ?? item.scopeID)
            + "/" + item.relativePath)
      })
    // Record intent before the first mutation. Failure here leaves every file untouched.
    try journal.save(receipt)
    for index in receipt.items.indices {
      let item = receipt.items[index].candidate
      do {
        try Task.checkCancellation()
        do { try await ensureStopped() } catch {
          for remaining in receipt.items.indices where remaining >= index {
            receipt.items[remaining].detail = error.localizedDescription
          }
          break
        }
        guard let record = records[item.id],
          let rule = try rules().first(where: { $0.id == item.scopeID })
        else { throw CodexStorageError.changed }
        try validateRoot(rule)
        try checkCanonical(record.url)
        let attributes = try files.attributesOfItem(atPath: record.url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
          try identity(attributes) == record.identity
        else { throw CodexStorageError.changed }
        receipt.items[index].status = .uncertain
        receipt.items[index].detail = String(localized: "操作中断时请在原目录及废纸篓核实；不会自动重试。")
        try journal.save(receipt)
        // Revalidate after journaling, immediately before the path-based Trash operation.
        try validateRoot(rule)
        try checkCanonical(record.url)
        guard try identity(files.attributesOfItem(atPath: record.url.path)) == record.identity
        else {
          throw CodexStorageError.changed
        }
        do {
          try trash(record.url)
          receipt.items[index].status = .trashed
          receipt.items[index].detail = String(localized: "可从废纸篓恢复；尚未保证释放磁盘空间。")
        } catch {
          // A failed Trash call may have moved the file before reporting an error.
          let current = try? identity(files.attributesOfItem(atPath: record.url.path))
          receipt.items[index].status = current == record.identity ? .failed : .uncertain
          receipt.items[index].detail = error.localizedDescription
        }
      } catch {
        receipt.items[index].status = .skipped
        receipt.items[index].detail = error.localizedDescription
        // Running-process and cancellation failures stop the entire remaining batch.
        if error is CancellationError || (error as? CodexStorageError) == .running {
          for remaining in receipt.items.indices where remaining > index {
            receipt.items[remaining].detail = error.localizedDescription
          }
          break
        }
      }
      do { try journal.save(receipt) } catch {
        receipt.warning = String(localized: "回执保存失败，已停止后续操作；请核对当前结果及废纸篓。")
        break
      }
    }
    receipt.finishedAt = now()
    do { try journal.save(receipt) } catch {
      receipt.warning = String(localized: "回执保存失败，已停止后续操作；请核对当前结果及废纸篓。")
    }
    return receipt
  }

  func lastReceipt() throws -> CodexStorageReceipt? {
    guard !executing else { throw CodexStorageError.busy }
    return try journal.load()
  }

  private func validateRoot(_ rule: Rule) throws {
    try checkCanonical(rule.url)
    let current = try identity(files.attributesOfItem(atPath: rule.url.path))
    guard let expected = roots[rule.id], current.device == expected.device,
      current.inode == expected.inode
    else {
      throw CodexStorageError.changed
    }
  }

  private func identity(_ attributes: [FileAttributeKey: Any]) throws -> Identity {
    guard let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
      let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
      let bytes = (attributes[.size] as? NSNumber)?.uint64Value,
      let modified = attributes[.modificationDate] as? Date,
      let created = attributes[.creationDate] as? Date,
      let links = (attributes[.referenceCount] as? NSNumber)?.uint64Value
    else { throw CodexStorageError.unavailable }
    return Identity(
      device: device, inode: inode, bytes: bytes, modified: modified, created: created, links: links
    )
  }

  private func checkCanonical(_ url: URL) throws {
    guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().path else {
      throw CodexStorageError.unavailable
    }
  }

  private func displayPath(_ url: URL) -> String {
    url.path.hasPrefix(home.path + "/") ? "~/" + url.path.dropFirst(home.path.count + 1) : url.path
  }

  private static func isProtected(_ name: String) -> Bool {
    let name = name.lowercased()
    return protectedNames.contains(name) || name.contains(".sqlite") || name.contains(".db")
      || name.hasSuffix(".jsonl")
  }

  private static func isDiagnosticLog(_ name: String) -> Bool {
    name.lowercased().range(of: #"\.log(?:\.\d+)?(?:\.gz)?$"#, options: .regularExpression) != nil
  }
}
