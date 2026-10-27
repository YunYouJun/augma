import CryptoKit
import Foundation

struct HomebrewCleanupPreview: Identifiable, Sendable {
  let id: UUID
  let version: String
  let report: String
  let itemCount: Int
  let estimatedBytes: UInt64?
  let canExecute: Bool
  let executionRestriction: String?
  let createdAt: Date
  fileprivate let fingerprint: String
}

struct HomebrewCleanupReceipt: Sendable {
  let succeeded: Bool
  let report: String
  let availableSpaceChange: Int64?
}

/// Homebrew owns deletion. Paths printed by dry-run are never turned into file operations.
actor HomebrewCleanupClient {
  typealias Run = @Sendable (URL, [String]) async throws -> CleanupCommandResult
  typealias Capacity = @Sendable () async -> Int64?
  enum Failure: LocalizedError {
    case notInstalled, command(String), stale, unsupported
    var errorDescription: String? {
      switch self {
      case .notInstalled: String(localized: "未找到 Homebrew；请自行安装后重试。")
      case .command(let report): String(localized: "Homebrew 未完成操作：") + "\n" + report
      case .stale: String(localized: "Homebrew 版本或预览已变化，请重新预览并确认。")
      case .unsupported: String(localized: "此 Homebrew 版本或报告格式尚未验证，仅提供预览。")
      }
    }
  }

  private let executable: URL?
  private let run: Run
  private let capacity: Capacity
  private let controlledEnvironment: @Sendable () -> Bool
  private var current: HomebrewCleanupPreview?
  private var busy = false

  init(executable: URL? = HomebrewCleanupClient.installedExecutable(),
       run: @escaping Run = { executable, arguments in
         try await CleanupCommandProcess().run(executable: executable, arguments: arguments,
                                              environment: HomebrewCleanupClient.environment())
       }, controlledEnvironment: @escaping @Sendable () -> Bool = HomebrewCleanupClient.environmentIsControlled,
       capacity: @escaping Capacity = {
         let path = FileManager.default.homeDirectoryForCurrentUser.path
         return (try? FileManager.default.attributesOfFileSystem(forPath: path)[.systemFreeSize] as? NSNumber)?.int64Value
       }) {
    self.executable = executable
    self.run = run
    self.capacity = capacity
    self.controlledEnvironment = controlledEnvironment
  }

  static func installedExecutable() -> URL? {
    ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
      .first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(filePath: $0) }
  }

  static func environment() -> [String: String] {
    // Do not forward model text, shell startup scripts, Ruby options or tokens.
    let inherited = ProcessInfo.processInfo.environment
    var result = inherited.filter { ["HOME", "USER", "LOGNAME", "TMPDIR"].contains($0.key) }
    result["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
    result["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    result["LC_ALL"] = "C"
    for key in ["HOMEBREW_NO_AUTO_UPDATE", "HOMEBREW_NO_ANALYTICS", "HOMEBREW_NO_AUTOREMOVE",
                "HOMEBREW_NO_ENV_HINTS", "HOMEBREW_NO_COLOR", "HOMEBREW_NO_INSTALL_CLEANUP", "HOMEBREW_NO_SUDO"] {
      result[key] = "1"
    }
    return result
  }

  static func environmentIsControlled() -> Bool {
    // brew.env can override command environment variables, including NO_AUTOREMOVE.
    // Do not read those potentially sensitive files or execute cleanup under overrides.
    let candidates = ["/etc/homebrew/brew.env", "/opt/homebrew/etc/homebrew/brew.env", "/usr/local/etc/homebrew/brew.env",
                      FileManager.default.homeDirectoryForCurrentUser.appending(path: ".homebrew/brew.env").path]
    return !candidates.contains { FileManager.default.fileExists(atPath: $0) }
  }

  func preview() async throws -> HomebrewCleanupPreview {
    guard !busy else { throw Failure.stale }
    busy = true; current = nil
    defer { busy = false }
    let preview = try await capturePreview()
    try Task.checkCancellation()
    current = preview
    return preview
  }

  func cleanup(previewID: UUID) async throws -> HomebrewCleanupReceipt {
    guard !busy, let expected = current, expected.id == previewID,
          Date().timeIntervalSince(expected.createdAt) < 300 else { throw Failure.stale }
    guard expected.canExecute else { throw Failure.unsupported }
    busy = true; current = nil
    defer { busy = false }
    let refreshed = try await capturePreview()
    guard refreshed.canExecute, refreshed.fingerprint == expected.fingerprint else { throw Failure.stale }
    try Task.checkCancellation()
    guard let executable else { throw Failure.notInstalled }
    guard controlledEnvironment() else { throw Failure.unsupported }
    let before = await capacity()
    let result = try await run(executable, ["cleanup"])
    let after = await capacity()
    // The shared volume can also change because other apps are writing.
    return HomebrewCleanupReceipt(succeeded: result.status == 0, report: Self.report(result),
                                  availableSpaceChange: before.flatMap { old in after.map { $0 - old } })
  }

  private func capturePreview() async throws -> HomebrewCleanupPreview {
    guard let executable else { throw Failure.notInstalled }
    let versionResult = try await run(executable, ["--version"])
    guard versionResult.status == 0 else { throw Failure.command(Self.report(versionResult)) }
    let version = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
    let result = try await run(executable, ["cleanup", "--dry-run"])
    guard result.status == 0 else { throw Failure.command(Self.report(result)) }
    try Task.checkCancellation()
    return Self.parse(version: version, result: result, controlledEnvironment: controlledEnvironment())
  }

  static func parse(version: String, result: CleanupCommandResult, controlledEnvironment: Bool = true) -> HomebrewCleanupPreview {
    let lines = result.output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    let items = lines.filter { $0.hasPrefix("Would remove:") || $0.hasPrefix("Would remove (") || $0.hasPrefix("Would prune ") }
    let estimate = lines.compactMap { line -> UInt64? in
      let pattern = #"^==> This operation would free approximately ([0-9]+(?:\.[0-9]+)?)([KMGT]?B) of disk space\.$"#
      guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let numberRange = Range(match.range(at: 1), in: line), let unitRange = Range(match.range(at: 2), in: line),
            let value = Double(line[numberRange]),
            let power = ["B": 0.0, "KB": 1, "MB": 2, "GB": 3, "TB": 4][String(line[unitRange])] else { return nil }
      // Homebrew Formatter.disk_usage_readable uses decimal units.
      let bytes = value * pow(1000, power)
      return bytes.isFinite && bytes >= 0 && bytes < Double(UInt64.max) ? UInt64(bytes) : nil
    }.first
    let recognized = lines.allSatisfy { items.contains($0) || $0.hasPrefix("==> This operation would free approximately ") }
    let supported = version.range(of: #"^Homebrew 7\.\d+\.\d+$"#, options: .regularExpression) != nil
    let restriction: String? = !controlledEnvironment
      ? String(localized: "检测到 Homebrew 环境配置，可能改变清理范围，仅提供预览。")
      : (!supported || !recognized || result.status != 0
         ? String(localized: "此 Homebrew 版本或报告格式尚未验证，仅提供预览。") : nil)
    let fingerprint = SHA256.hash(data: Data((version + "\n" + lines.sorted().joined(separator: "\n")
      + "\n" + result.diagnostics).utf8)).map { String(format: "%02x", $0) }.joined()
    return HomebrewCleanupPreview(id: UUID(), version: version, report: report(result), itemCount: items.count,
      estimatedBytes: estimate, canExecute: restriction == nil && !items.isEmpty, executionRestriction: restriction,
      createdAt: .now, fingerprint: fingerprint)
  }

  private static func report(_ result: CleanupCommandResult) -> String {
    [result.output, result.diagnostics].filter { !$0.isEmpty }.joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
