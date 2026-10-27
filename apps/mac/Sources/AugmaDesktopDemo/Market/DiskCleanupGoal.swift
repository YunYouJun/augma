import Foundation

struct DiskCleanupGoal: Equatable, Sendable {
  let request: String
  let targetBytes: UInt64?
  var keepModels = true
  var keepRecentProjects = true

  static let example = "帮我尽量腾出 20 GB，保留模型和最近项目。"

  static func parse(_ request: String) -> Self? {
    let text = request.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 500,
          text.range(of: "清理磁盘|磁盘清理|清理硬盘|腾出|释放.*空间|free.*(?:space|[gm]b)|clean.*disk|空け|ディスク.*(?:整理|クリーン)|容量.*解放", options: [.regularExpression, .caseInsensitive]) != nil,
          text.range(of: "不要|先别|请别|^别|don't|do not|never|しない|只清理|仅清理|only", options: [.regularExpression, .caseInsensitive]) == nil,
          supportsPreservation(in: text)
    else { return nil }
    let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(GiB|MiB|TiB|GB|MB|TB)"#, options: .caseInsensitive)
    var target: UInt64?
    if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
       let number = Range(match.range(at: 1), in: text), let unit = Range(match.range(at: 2), in: text),
       let value = Double(text[number]) {
      let units: [String: Double] = ["mb": 1e6, "gb": 1e9, "tb": 1e12, "mib": 1_048_576, "gib": 1_073_741_824, "tib": 1_099_511_627_776]
      let bytes = value * (units[String(text[unit]).lowercased()] ?? 0)
      guard bytes.isFinite, bytes > 0, bytes <= 10_995_116_277_760 else { return nil }
      target = UInt64(bytes)
    }
    return Self(request: text, targetBytes: target)
  }

  private static func supportsPreservation(in text: String) -> Bool {
    // Unknown protection clauses must not silently become permission to offer
    // those files. Broader natural-language constraints need a richer rule model.
    guard let regex = try? NSRegularExpression(pattern: #"(?:保留|keep(?:ing)?|preserv(?:e|ing))\s*([^，,。.!！;；\n]+)"#,
                                                options: .caseInsensitive) else { return false }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).allSatisfy { match in
      guard let range = Range(match.range(at: 1), in: text) else { return false }
      let remainder = String(text[range]).replacingOccurrences(
        of: #"模型|最近|近期|项目|源码|工程|所有|全部|本地|我的|和|与|及|、|models?|recent|projects?|source|code|all|my|and|\s"#,
        with: "", options: [.regularExpression, .caseInsensitive])
      return remainder.isEmpty
    }
  }
}

struct DiskCleanupPlan: Identifiable, Sendable {
  var id: UUID
  let goal: DiskCleanupGoal
  let scope: URL
  let createdAt: Date
  var candidates: [CleanupCandidate]
  let occupancy: MoleDiskReport
  let scanIncomplete: Bool
  let protectedCount: Int
  var summary: String
  var usedAI = false

  var bytes: UInt64 { candidates.reduce(0) { $0.addingReportingOverflow($1.bytes).overflow ? $0 : $0 + $1.bytes } }

  func acceptsApproval(planID: UUID, ids: Set<UUID>, scope: URL, at date: Date = .now) -> Bool {
    let age = date.timeIntervalSince(createdAt)
    return id == planID && !ids.isEmpty && age >= 0 && age < 300
      && self.scope.standardizedFileURL == scope.standardizedFileURL
      && ids.isSubset(of: Set(candidates.map(\.id)))
      && candidates.filter { ids.contains($0.id) }.allSatisfy { Self.permits($0, goal: goal, scope: self.scope) }
  }

  static func build(goal: DiskCleanupGoal, scope: URL, scan: CleanupScan, occupancy: MoleDiskReport) -> Self {
    let allowed = scan.candidates.filter { permits($0, goal: goal, scope: scope) }.sorted { $0.bytes > $1.bytes }
    var selected: [CleanupCandidate] = [], total: UInt64 = 0
    for item in allowed {
      if let target = goal.targetBytes, total >= target { break }
      let sum = total.addingReportingOverflow(item.bytes)
      guard !sum.overflow else { continue }
      selected.append(item); total = sum.partialValue
    }
    return Self(id: UUID(), goal: goal, scope: scope, createdAt: .now, candidates: selected,
                occupancy: occupancy, scanIncomplete: scan.incomplete,
                protectedCount: scan.candidates.count - allowed.count,
                summary: String(localized: "已按保留规则生成本地计划，请核对具体项目。"))
  }

  static func permits(_ candidate: CleanupCandidate, goal: DiskCleanupGoal, scope: URL) -> Bool {
    let root = scope.standardizedFileURL.path
    guard candidate.url.standardizedFileURL.path.hasPrefix(root == "/" ? "/" : root + "/") else { return false }
    // Do not infer source-project activity from a build cache's mtime. Until a
    // reliable mapping is available, preserving recent projects retains ALL Xcode caches.
    if goal.keepRecentProjects && candidate.category == .xcode { return false }
    if goal.keepModels {
      let name = candidate.url.lastPathComponent.lowercased()
      if name.range(of: "model|模型|llama|ollama|huggingface|checkpoint|weights|gguf|safetensors", options: .regularExpression) != nil { return false }
    }
    return true
  }
}

enum DiskCleanupPlanning {
  static func messages(_ plan: DiskCleanupPlan) throws -> [[String: String]] {
    let body: [String: Any] = [
      "targetBytes": plan.goal.targetBytes.map { $0 as Any } ?? NSNull(),
      "keepModels": plan.goal.keepModels, "keepRecentProjects": plan.goal.keepRecentProjects,
      "incomplete": plan.scanIncomplete || plan.occupancy.incomplete,
      "candidates": plan.candidates.prefix(12).map {
        ["id": $0.id.uuidString, "category": $0.category.rawValue, "bytes": $0.bytes] as [String: Any]
      },
    ]
    return try DeepSeekClient.validate([
      ["role": "system", "content": """
        You help plan disk cleanup in a native Mac app. Answer in Simplified Chinese.
        Use only the supplied numeric data. Return JSON only: {"summary":string,"ids":[string]}.
        Summary must be at most 300 characters. IDs must be a unique subset of supplied candidate IDs,
        at most 12. Rank useful candidates, mention any target shortfall or incomplete scan.
        Never output commands, paths, additional fields, or claim cleanup happened.
        All recent projects and model storage are protected. Unknown project caches were excluded.
        These candidates will be moved to Trash, which does NOT free space until the user empties it.
        Candidate bytes are approximate; do not promise the same amount of actual free space.
        """],
      ["role": "user", "content": String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self)],
    ])
  }

  static func apply(_ content: String, to plan: DiskCleanupPlan) throws -> DiskCleanupPlan {
    guard content.utf8.count <= 8_192,
          let body = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
          Set(body.keys) == ["summary", "ids"], let summary = body["summary"] as? String,
          !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, summary.count <= 300,
          let ids = body["ids"] as? [String], ids.count <= 12, Set(ids).count == ids.count else {
      throw DeepSeekClient.Failure.invalidResponse
    }
    let allowed = Dictionary(plan.candidates.prefix(12).map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
    guard ids.allSatisfy({ allowed[$0] != nil }) else { throw DeepSeekClient.Failure.invalidResponse }
    var result = plan
    result.id = UUID()
    result.summary = summary
    result.candidates = ids.compactMap { allowed[$0] }
    result.usedAI = true
    return result
  }
}
