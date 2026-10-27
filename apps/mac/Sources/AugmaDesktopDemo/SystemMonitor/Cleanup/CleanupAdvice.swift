import Foundation

struct CleanupAdvice: Equatable, Sendable {
  let summary: String
  let categories: [CleanupCategory]
  let applications: [String]

  static func messages(scan: CleanupScan, snapshot: SystemSnapshot, locale: String,
                       homebrew: HomebrewCleanupPreview? = nil) throws -> [[String: String]] {
    let applications = Array((snapshot.applicationMemory?.applications ?? []).prefix(10))
    var payload: [String: Any] = [
      "scanIncomplete": scan.incomplete,
      "cleanup": CleanupCategory.allCases.map { category in
        let candidates = scan.candidates.filter { $0.category == category }
        return ["category": category.rawValue, "count": candidates.count,
                "bytes": candidates.reduce(UInt64(0)) { $0 + $1.bytes }] as [String: Any]
      },
      "applications": applications.enumerated().map { index, usage in
        ["id": "app\(index + 1)", "bytes": usage.physicalFootprint,
         "partial": usage.unreadableProcessCount > 0] as [String: Any]
      },
      "disks": snapshot.disks.prefix(5).map { ["total": $0.total, "available": $0.available] },
    ]
    if let memory = snapshot.memory {
      payload["memory"] = ["total": memory.total, "used": memory.used, "compressed": memory.compressed,
                           "swap": memory.swapUsed, "pressure": memory.pressure.rawValue]
    }
    if let homebrew {
      var tool: [String: Any] = ["count": homebrew.itemCount, "previewIsExhaustive": false]
      if let bytes = homebrew.estimatedBytes { tool["estimatedBytes"] = bytes }
      payload["homebrew"] = tool
    }
    let data = try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)
    let language = locale.hasPrefix("en") ? "English" : locale.hasPrefix("ja") ? "Japanese" : "Simplified Chinese"
    return try DeepSeekClient.validate([
      ["role": "system", "content": """
        You advise on macOS cleanup using only the attached numeric snapshot. Answer in \(language).
        Output JSON only: {"summary": string, "categories": [string], "applications": [string]}.
        Summary: at most 3 brief sentences, 600 characters, plain text. Categories: only installers or xcode
        with count > 0. Applications: at most 5 supplied app IDs, suggesting review before normal quit.
        Never output commands, paths, shell scripts or claim anything has been cleaned or quit.
        High used RAM alone is not a fault; prioritize memory pressure, and explain uncertainty if unavailable.
        App footprint is approximate and may be partial; quitting does not guarantee a byte count reclaimed.
        Candidates are installers or rebuildable Xcode DerivedData unmodified for 7 days. Users must review
        each item; rebuilding caches costs time. Moving files to Trash does not immediately free disk space.
        Never suggest deleting swap, system files, personal documents or forcing termination.
        If a Homebrew numeric preview is supplied, you may suggest reviewing its separate cleanup panel.
        Its estimate is approximate, its preview is not exhaustive, and its cleanup permanently removes
        tool-managed old versions, downloads and logs. Do not add Homebrew to the categories array.
        """],
      ["role": "user", "content": String(decoding: data, as: UTF8.self)],
    ])
  }

  static func parse(_ content: String, scan: CleanupScan, applicationIDs: Set<String>) throws -> CleanupAdvice {
    guard content.utf8.count <= 8_192, let data = content.data(using: .utf8),
      let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      Set(body.keys) == ["summary", "categories", "applications"],
      let summary = body["summary"] as? String,
      !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, summary.count <= 600,
      let categories = body["categories"] as? [String], categories.count <= 2,
      let applications = body["applications"] as? [String], applications.count <= 5,
      Set(categories).count == categories.count, Set(applications).count == applications.count,
      Set(applications).isSubset(of: applicationIDs)
    else { throw DeepSeekClient.Failure.invalidResponse }
    let allowed = Set(scan.candidates.map { $0.category.rawValue })
    guard Set(categories).isSubset(of: allowed) else { throw DeepSeekClient.Failure.invalidResponse }
    return CleanupAdvice(summary: summary, categories: categories.compactMap(CleanupCategory.init(rawValue:)),
                         applications: applications)
  }
}
