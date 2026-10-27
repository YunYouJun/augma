import Foundation

struct MoleInstallation: Equatable, Sendable {
  var version: String?
  var homebrewAvailable: Bool
  var supported: Bool { version == MoleToolClient.supportedVersion }
}

struct MoleDiskEntry: Identifiable, Decodable, Sendable {
  let path: String
  let size: UInt64
  var scan_status: String? = nil
  var complete: Bool { scan_status == "complete" }
  var name: String { URL(filePath: path).lastPathComponent }
  var id: String { path }
}

struct MoleDiskReport: Sendable {
  let entries: [MoleDiskEntry]
  let incomplete: Bool
  let measuredBytes: UInt64?

  static func parse(_ output: String, scope: URL) throws -> Self {
    struct Document: Decodable {
      var path: String
      var entries: [MoleDiskEntry]
      var scan_status: String?
      var total_size: UInt64?
    }
    guard output.utf8.count <= 4_194_304,
          let document = try? JSONDecoder().decode(Document.self, from: Data(output.utf8)),
          URL(filePath: document.path).standardizedFileURL.path == scope.standardizedFileURL.path,
          document.entries.count <= 20_000 else { throw MoleToolError.invalidReport }
    let root = scope.standardizedFileURL.path
    guard document.entries.allSatisfy({ entry in
      entry.path.hasPrefix(root == "/" ? "/" : root + "/")
        && URL(filePath: entry.path).standardizedFileURL.path == entry.path
    }) else { throw MoleToolError.invalidReport }
    // These are occupancy rows, never authority to delete their paths.
    let unique = Dictionary(document.entries.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    return Self(entries: unique.values.sorted { $0.size > $1.size }.prefix(20).map { $0 },
                incomplete: document.scan_status != "complete" || document.entries.contains { !$0.complete },
                measuredBytes: document.total_size)
  }
}

enum MoleToolError: LocalizedError {
  case missing, unsupported, homebrewMissing, environment, failed(String), invalidReport
  var errorDescription: String? {
    switch self {
    case .missing: String(localized: "请先在应用市场安装 Mole CLI。")
    case .unsupported: String(localized: "Mole 版本尚未适配，请保留当前版本并查看诊断。")
    case .homebrewMissing: String(localized: "需要已安装的 Homebrew；Augma 不会自动安装包管理器。")
    case .environment: String(localized: "检测到 Homebrew 环境配置，请在终端安装 Mole 后刷新。")
    case .failed(let report): String(localized: "Mole 操作未完成：") + "\n" + String(report.prefix(4_000))
    case .invalidReport: String(localized: "无法验证 Mole 的扫描报告，请查看版本或缩小扫描范围。")
    }
  }
}

protocol MoleToolProviding: Sendable {
  func inspect() async throws -> MoleInstallation
  func install() async throws -> MoleInstallation
  func analyze(scope: URL) async throws -> MoleDiskReport
}

/// A fixed catalog entry, not a general shell or package-name execution surface.
actor MoleToolClient: MoleToolProviding {
  static let supportedVersion = "1.64.0"
  typealias Run = @Sendable (URL, [String], Duration) async throws -> CleanupCommandResult
  private let discoverMole: @Sendable () -> URL?
  private let brew: URL?
  private let controlledEnvironment: @Sendable () -> Bool
  private let run: Run

  init(discoverMole: @escaping @Sendable () -> URL? = {
    ["/opt/homebrew/bin/mo", "/usr/local/bin/mo"].first { FileManager.default.isExecutableFile(atPath: $0) }
      .map { URL(filePath: $0) }
  }, brew: URL? = HomebrewCleanupClient.installedExecutable(),
       controlledEnvironment: @escaping @Sendable () -> Bool = HomebrewCleanupClient.environmentIsControlled,
       run: @escaping Run = { executable, arguments, timeout in
         var environment = HomebrewCleanupClient.environment()
         environment["MO_NO_OPLOG"] = "1"
         environment["NO_COLOR"] = "1"
         environment["TERM"] = "dumb"
         return try await CleanupCommandProcess(timeout: timeout, maximumOutput: 4_194_304)
           .run(executable: executable, arguments: arguments, environment: environment)
       }) {
    self.discoverMole = discoverMole
    self.brew = brew
    self.controlledEnvironment = controlledEnvironment
    self.run = run
  }

  func inspect() async throws -> MoleInstallation {
    guard let executable = discoverMole() else { return .init(version: nil, homebrewAvailable: brew != nil) }
    let result = try await run(executable, ["--version"], .seconds(15))
    guard result.status == 0 else { throw MoleToolError.failed(result.diagnostics) }
    let regex = try NSRegularExpression(pattern: #"(?<![\d.])(\d+\.\d+\.\d+)(?![\d.])"#)
    let version = regex.firstMatch(in: result.output, range: NSRange(result.output.startIndex..., in: result.output))
      .flatMap { Range($0.range(at: 1), in: result.output) }.map { String(result.output[$0]) }
    guard let version else { throw MoleToolError.invalidReport }
    return .init(version: version, homebrewAvailable: brew != nil)
  }

  func install() async throws -> MoleInstallation {
    let before = try await inspect()
    if before.version != nil { return before } // Never silently upgrade an existing user installation.
    guard let brew else { throw MoleToolError.homebrewMissing }
    guard controlledEnvironment() else { throw MoleToolError.environment }
    let info = try await run(brew, ["info", "--json=v2", "homebrew/core/mole"], .seconds(30))
    guard info.status == 0,
          let body = try? JSONSerialization.jsonObject(with: Data(info.output.utf8)) as? [String: Any],
          let formulae = body["formulae"] as? [[String: Any]], formulae.count == 1,
          formulae[0]["name"] as? String == "mole",
          formulae[0]["full_name"] as? String == "mole", formulae[0]["tap"] as? String == "homebrew/core",
          let versions = formulae[0]["versions"] as? [String: Any], versions["stable"] as? String == Self.supportedVersion
    else { throw MoleToolError.unsupported }
    try Task.checkCancellation()
    guard controlledEnvironment() else { throw MoleToolError.environment }
    let result = try await run(brew, ["install", "--formula", "homebrew/core/mole"], .seconds(300))
    guard result.status == 0 else { throw MoleToolError.failed(result.output + "\n" + result.diagnostics) }
    let installed = try await inspect()
    guard installed.version != nil else { throw MoleToolError.missing }
    return installed
  }

  func analyze(scope: URL) async throws -> MoleDiskReport {
    guard let executable = discoverMole() else { throw MoleToolError.missing }
    guard try await inspect().supported else { throw MoleToolError.unsupported }
    try Task.checkCancellation()
    let result = try await run(executable, ["analyze", "--json", scope.path], .seconds(45))
    guard result.status == 0 else { throw MoleToolError.failed(result.diagnostics) }
    return try MoleDiskReport.parse(result.output, scope: scope)
  }
}
