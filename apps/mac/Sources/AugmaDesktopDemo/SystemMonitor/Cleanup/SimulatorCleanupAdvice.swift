import Foundation

struct SimulatorCleanupAdvice: Equatable, Sendable {
  let summary: String
  let recommendedIDs: [String]

  static func messages(scan: SimulatorCleanupScan, locale: String) throws -> [[String: String]] {
    let rows: [[String: Any]] = scan.items.prefix(20).enumerated().map { index, item in
      var row: [String: Any] = ["id": "item\(index + 1)", "kind": item.kind.rawValue,
        "canDelete": item.canDelete, "dependentDeviceCount": item.dependentDeviceCount,
        "runningOrUnknown": item.kind == .device && item.state != "Shutdown"]
      if let bytes = item.bytes { row["estimatedBytes"] = bytes }
      if let used = item.lastUsedAt {
        row["lastUsedHoursAgo"] = Int(max(0, min(876_000, scan.createdAt.timeIntervalSince(used) / 3_600)))
      }
      return row
    }
    let payload: [String: Any] = ["items": rows, "omittedCount": max(0, scan.items.count - rows.count),
      "incomplete": scan.incomplete, "scope": "defaultDeviceSetOnly", "otherDeviceSetsVerified": false]
    let data = try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)
    let language = locale.hasPrefix("en") ? "English" : locale.hasPrefix("ja") ? "Japanese" : "Simplified Chinese"
    return try DeepSeekClient.validate([
      ["role": "system", "content": """
        Advise on the anonymous macOS simulator inventory in \(language). Output JSON only:
        {"summary": string, "recommendations": [string]}. Summary: nonempty plain text, at most
        600 characters and 3 short sentences. Recommend at most 20 unique supplied item IDs whose
        canDelete is true, for user review only. Running/unknown devices and dependent runtimes
        are protected. Old or large does not prove disposable; last-use metadata may be unknown.
        lastUsedHoursAgo is elapsed whole hours, not a calendar date. Describe elapsed time;
        fewer than 24 hours ago does not necessarily mean today. Do not infer a calendar date.
        Deleting a device permanently removes its installed apps, sign-ins and test data.
        A deleted runtime needs downloading again, and deleting it may affect simulator services.
        Only the default device set was scanned. Zero dependencies or no running devices in this
        inventory does not prove that no other device sets use the shared runtime. Other device
        sets are unknown. Before runtime deletion the user must inspect other device sets and
        explicitly confirm they have closed their simulators; never infer this acknowledgement.
        Explain rebuilding/downloading costs and uncertainty; size estimates do not guarantee
        disk space reclaimed. Never output commands, paths, scripts, extra fields or approvals,
        and never claim anything was deleted. The user must manually select and confirm each item.
        """],
      ["role": "user", "content": String(decoding: data, as: UTF8.self)],
    ])
  }

  static func parse(_ content: String, scan: SimulatorCleanupScan) throws -> Self {
    guard content.utf8.count <= 8_192,
          let body = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
          Set(body.keys) == ["summary", "recommendations"],
          let summary = body["summary"] as? String,
          !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, summary.count <= 600,
          let recommendations = body["recommendations"] as? [String], recommendations.count <= 20,
          Set(recommendations).count == recommendations.count,
          safeSummary(summary) else { throw DeepSeekClient.Failure.invalidResponse }
    let allowed = Dictionary(uniqueKeysWithValues: scan.items.prefix(20).enumerated().compactMap { index, item in
      item.canDelete ? ("item\(index + 1)", item.id) : nil
    })
    guard recommendations.allSatisfy({ allowed[$0] != nil }) else { throw DeepSeekClient.Failure.invalidResponse }
    return .init(summary: summary, recommendedIDs: recommendations.compactMap { allowed[$0] })
  }

  private static func safeSummary(_ value: String) -> Bool {
    // Model text is only presentation, but reject obvious command/path payloads as malformed advice.
    !["/", "\\", "`", "\u{0000}", "$", ";"].contains(where: value.contains)
      && value.range(of: #"(?i)\b(?:simctl|sudo|xcrun|rm\s+-|bash|zsh|curl)\b"#, options: .regularExpression) == nil
  }
}
