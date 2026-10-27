import Foundation

/// Only simctl owns device/runtime deletion. Reported paths are never file-operation inputs.
actor SimulatorCleanupClient: SimulatorCleanupProviding {
  typealias Run = @Sendable (URL, [String]) async throws -> CleanupCommandResult
  typealias Capacity = @Sendable () async -> Int64?
  enum Failure: LocalizedError {
    case command(String), invalidInventory, stale, protectedItem
    var errorDescription: String? {
      switch self {
      case .command(let report): String(localized: "无法读取模拟器或完成操作，请检查 Xcode 命令行工具。") + "\n" + report
      case .invalidInventory: String(localized: "无法验证模拟器清单，未启用删除。请更新 Xcode 后重新扫描。")
      case .stale: String(localized: "模拟器扫描已过期或确认范围已变化，请重新扫描并确认。")
      case .protectedItem: String(localized: "所选项目当前受到保护，请重新扫描并查看原因。")
      }
    }
  }

  private let executable = URL(filePath: "/usr/bin/xcrun")
  private let run: Run
  private let clock: @Sendable () -> Date
  private let capacity: Capacity
  private let pause: @Sendable () async -> Void
  private var current: SimulatorCleanupScan?
  private var deviceModels: [String: String] = [:]
  private var busy = false

  init(run: @escaping Run = { executable, arguments in
    try await CleanupCommandProcess(timeout: .seconds(45), maximumOutput: 2_097_152)
      .run(executable: executable, arguments: arguments, environment: SimulatorCleanupClient.environment())
  }, clock: @escaping @Sendable () -> Date = { .now }, capacity: @escaping Capacity = {
    let path = FileManager.default.homeDirectoryForCurrentUser.path
    return (try? FileManager.default.attributesOfFileSystem(forPath: path)[.systemFreeSize] as? NSNumber)?.int64Value
  }, pause: @escaping @Sendable () async -> Void = { try? await Task.sleep(for: .milliseconds(200)) }) {
    self.run = run
    self.clock = clock
    self.capacity = capacity
    self.pause = pause
  }

  static func environment() -> [String: String] {
    let inherited = ProcessInfo.processInfo.environment
    var result = inherited.filter { ["HOME", "USER", "LOGNAME", "TMPDIR"].contains($0.key) }
    result["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
    result["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    result["LC_ALL"] = "C"
    // Use the selected Xcode. Never inherit injected executable, loader, or shell settings.
    return result
  }

  func scan() async throws -> SimulatorCleanupScan {
    guard !busy else { throw Failure.stale }
    try Task.checkCancellation()
    busy = true
    current = nil
    defer { busy = false }
    do {
      deviceModels = Self.parseDeviceModels(try await read(["simctl", "list", "devicetypes", "--json"]))
    } catch {
      try Task.checkCancellation()
      if error is CancellationError { throw error }
      deviceModels = [:] // Icon metadata cannot turn an otherwise valid inventory into a deletion failure.
    }
    try Task.checkCancellation()
    let result = try await inventory()
    try Task.checkCancellation()
    current = result
    return result
  }

  func delete(scanID: UUID, ids: Set<String>, runtimeScopeAcknowledged: Bool) async throws -> SimulatorCleanupReceipt {
    guard !busy, let expected = current, expected.id == scanID, !ids.isEmpty,
          validAge(expected.createdAt) else { throw Failure.stale }
    let selected = expected.items.filter { ids.contains($0.id) }
    guard selected.count == ids.count else { throw Failure.stale }
    guard runtimeScopeAcknowledged || !selected.contains(where: { $0.kind == .runtime }) else {
      throw Failure.protectedItem
    }
    guard selected.allSatisfy(\.canDelete) else { throw Failure.protectedItem }
    try Task.checkCancellation()
    busy = true
    current = nil // A confirmation can be consumed only once, including partial failures.
    defer { busy = false }

    // A complete initial read proves both command formats are still supported before any mutation.
    _ = try await inventory()
    let before = await capacity()
    var results: [SimulatorCleanupResult] = []
    for item in selected {
      do {
        guard validAge(expected.createdAt) else {
          results.append(.init(item: item, status: .skipped,
                               message: String(localized: "确认已超过五分钟，请重新扫描。")))
          continue
        }
        try Task.checkCancellation()
        let fresh = try await inventory()
        guard let actual = fresh.items.first(where: { $0.id == item.id }), actual == item, actual.canDelete else {
          results.append(.init(item: item, status: .skipped,
                               message: String(localized: "项目状态、占用或依赖已变化，请重新扫描。")))
          continue
        }
        guard validAge(expected.createdAt) else {
          results.append(.init(item: item, status: .skipped,
                               message: String(localized: "确认已超过五分钟，请重新扫描。")))
          continue
        }
        try Task.checkCancellation()
        // Rechecking is best effort; simctl remains responsible for the final operation.
        let arguments = item.kind == .device
          ? ["simctl", "delete", item.identifier]
          : ["simctl", "runtime", "delete", item.identifier]
        let result = try await run(executable, arguments)
        guard result.status == 0 else {
          results.append(.init(item: item, status: .failed,
                               message: String(localized: "工具未成功完成；请重新扫描确认当前状态。") + "\n" + Self.report(result)))
          continue
        }
        // Runtime deletion can return before its asynchronous inventory entry disappears.
        var removed = false
        for attempt in 0..<3 {
          if attempt > 0 { await pause() }
          guard let check = try? await inventory() else { break }
          if !check.items.contains(where: { $0.id == item.id }) { removed = true; break }
        }
        results.append(.init(item: item, status: removed ? .deleted : .pending,
          message: removed ? String(localized: "已核对从模拟器清单移除。")
            : String(localized: "工具已接受删除，尚未核对移除；请稍后重新扫描。")))
      } catch {
        results.append(.init(item: item, status: .failed,
          message: String(localized: "操作未完成或状态无法核对；可能已部分生效，请重新扫描。") + "\n" + error.localizedDescription))
      }
    }
    let after = await capacity()
    let delta: Int64? = before.flatMap { old in
      after.flatMap { value in
        let (difference, overflow) = value.subtractingReportingOverflow(old)
        return overflow ? nil : difference
      }
    }
    return .init(results: results, availableSpaceChange: delta, createdAt: clock())
  }

  private func validAge(_ createdAt: Date) -> Bool {
    let age = clock().timeIntervalSince(createdAt)
    return age >= 0 && age < 300
  }

  private func inventory() async throws -> SimulatorCleanupScan {
    let devices = try await read(["simctl", "list", "devices", "--json"])
    let runtimes = try await read(["simctl", "runtime", "list", "--json"])
    return try Self.parse(devices: devices, runtimes: runtimes, deviceModels: deviceModels, createdAt: clock())
  }

  private func read(_ arguments: [String]) async throws -> String {
    let result = try await run(executable, arguments)
    guard result.status == 0 else { throw Failure.command(Self.report(result)) }
    guard result.output.utf8.count + result.diagnostics.utf8.count <= 2_097_152 else { throw Failure.invalidInventory }
    return result.output
  }

  static func parse(devices: String, runtimes: String, deviceTypes: String? = nil,
                    createdAt: Date = .now) throws -> SimulatorCleanupScan {
    try parse(devices: devices, runtimes: runtimes, deviceModels: parseDeviceModels(deviceTypes), createdAt: createdAt)
  }

  private static func parse(devices: String, runtimes: String, deviceModels: [String: String],
                            createdAt: Date) throws -> SimulatorCleanupScan {
    let decoder = JSONDecoder()
    guard devices.utf8.count <= 2_097_152, runtimes.utf8.count <= 2_097_152,
          let deviceDocument = try? decoder.decode(DeviceDocument.self, from: Data(devices.utf8)),
          let runtimeDocument = try? decoder.decode([String: RuntimeRecord].self, from: Data(runtimes.utf8)),
          deviceDocument.devices.values.reduce(0, { $0 + $1.count }) <= 2_000,
          runtimeDocument.count <= 200 else { throw Failure.invalidInventory }
    var items: [SimulatorCleanupItem] = []
    var warnings: Set<String> = []
    var identifiers: Set<String> = []
    var dependencies: [String: Int] = [:]
    let hasActiveDevices = deviceDocument.devices.values.joined().contains { $0.state != "Shutdown" }
    for (runtimeID, records) in deviceDocument.devices {
      guard validRuntimeID(runtimeID) else { throw Failure.invalidInventory }
      for record in records {
        guard let uuid = UUID(uuidString: record.udid), identifiers.insert("device:" + uuid.uuidString).inserted,
              !record.name.isEmpty, record.name.count <= 512 else { throw Failure.invalidInventory }
        dependencies[runtimeID, default: 0] += 1
        let state = record.state ?? "Unknown"
        let restriction: String? = state != "Shutdown"
          ? String(localized: "设备正在运行或状态未知，请先在模拟器中关闭设备。")
          : record.isAvailable == nil ? String(localized: "无法验证设备可用状态，仅供查看。") : nil
        let date = parseDate(record.lastUsedAt)
        if record.lastUsedAt != nil && date == nil { warnings.insert(String(localized: "部分最后使用时间无法读取。")) }
        if record.dataPathSize == nil { warnings.insert(String(localized: "部分设备占用未知，合计仅包含已知估算。")) }
        let model = record.deviceTypeIdentifier.flatMap { deviceModels[$0] }
        if model == nil { warnings.insert(String(localized: "部分设备型号无法读取，已使用通用图标。")) }
        items.append(.init(kind: .device, identifier: uuid.uuidString, name: record.name, runtimeIdentifier: runtimeID,
          version: runtimeVersion(runtimeID), build: nil, state: state,
          bytes: record.dataPathSize, lastUsedAt: date, isAvailable: record.isAvailable,
          dependentDeviceCount: 0, restriction: restriction, deviceTypeIdentifier: record.deviceTypeIdentifier,
          modelIdentifier: model))
      }
    }
    for (key, record) in runtimeDocument {
      guard let uuid = UUID(uuidString: key), let identifier = UUID(uuidString: record.identifier), uuid == identifier,
            identifiers.insert("runtime:" + uuid.uuidString).inserted,
            validRuntimeID(record.runtimeIdentifier) else { throw Failure.invalidInventory }
      let count = dependencies[record.runtimeIdentifier, default: 0]
      let restriction: String?
      if count > 0 { restriction = String(localized: "默认设备集仍有关联设备；请先检查并删除不再需要的设备后重新扫描。") }
      else if hasActiveDevices { restriction = String(localized: "删除运行时可能影响其他设备集；请先关闭默认设备集中的所有设备，并检查其他设备集。") }
      else if record.deletable != true || record.state != "Ready" || record.version?.isEmpty != false || record.build?.isEmpty != false {
        restriction = String(localized: "运行时状态或删除能力无法验证，仅供查看。")
      } else { restriction = nil }
      let date = parseDate(record.lastUsedAt)
      if record.lastUsedAt != nil && date == nil { warnings.insert(String(localized: "部分最后使用时间无法读取。")) }
      if record.sizeBytes == nil { warnings.insert(String(localized: "部分运行时占用未知，合计仅包含已知估算。")) }
      let platform = record.runtimeIdentifier.split(separator: ".").last?.split(separator: "-").first.map(String.init) ?? "Simulator"
      let name = platform + " " + (record.version ?? runtimeVersion(record.runtimeIdentifier) ?? "?")
      items.append(.init(kind: .runtime, identifier: uuid.uuidString, name: name, runtimeIdentifier: record.runtimeIdentifier,
        version: record.version, build: record.build, state: record.state ?? "Unknown", bytes: record.sizeBytes,
        lastUsedAt: date, isAvailable: record.state == "Ready", dependentDeviceCount: count, restriction: restriction))
    }
    items.sort { lhs, rhs in
      if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
      if lhs.bytes != rhs.bytes {
        if let left = lhs.bytes, let right = rhs.bytes { return left > right }
        return lhs.bytes != nil
      }
      return (lhs.name, lhs.id) < (rhs.name, rhs.id)
    }
    return .init(createdAt: createdAt, items: items, warnings: warnings.sorted())
  }

  private static func validRuntimeID(_ value: String) -> Bool {
    value.range(of: #"^com\.apple\.CoreSimulator\.SimRuntime\.[A-Za-z0-9-]+$"#, options: .regularExpression) != nil
  }

  /// One catalog per explicit scan; subsequent execution checks reuse this immutable mapping.
  private static func parseDeviceModels(_ output: String?) -> [String: String] {
    guard let output, output.utf8.count <= 2_097_152,
          let document = try? JSONDecoder().decode(DeviceTypeDocument.self, from: Data(output.utf8)),
          document.devicetypes.count <= 4_000 else { return [:] }
    var models: [String: String] = [:]
    for record in document.devicetypes {
      guard record.identifier.count <= 200,
            record.identifier.range(of: #"^com\.apple\.CoreSimulator\.SimDeviceType\.[A-Za-z0-9.-]+$"#,
                                    options: .regularExpression) != nil,
            let model = record.modelIdentifier, model.count <= 80,
            model.range(of: #"^[A-Za-z][A-Za-z0-9]{0,63}[0-9],[0-9]{1,5}$"#,
                        options: .regularExpression) != nil else { continue }
      if let previous = models[record.identifier], previous != model { return [:] }
      models[record.identifier] = model
    }
    return models
  }

  private static func runtimeVersion(_ identifier: String) -> String? {
    guard let tail = identifier.split(separator: ".").last else { return nil }
    let components = tail.split(separator: "-").dropFirst()
    return components.isEmpty ? nil : components.joined(separator: ".")
  }

  private static func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value)
  }

  private static func report(_ result: CleanupCommandResult) -> String {
    String([result.output, result.diagnostics].filter { !$0.isEmpty }.joined(separator: "\n").prefix(4_000))
  }

  private struct DeviceDocument: Decodable { let devices: [String: [DeviceRecord]] }
  private struct DeviceTypeDocument: Decodable { let devicetypes: [DeviceTypeRecord] }
  private struct DeviceTypeRecord: Decodable {
    let identifier: String
    let modelIdentifier: String?
  }
  private struct DeviceRecord: Decodable {
    let udid: String
    let name: String
    let state: String?
    let isAvailable: Bool?
    let dataPathSize: UInt64?
    let lastUsedAt: String?
    let deviceTypeIdentifier: String?
  }
  private struct RuntimeRecord: Decodable {
    let identifier: String
    let runtimeIdentifier: String
    let version: String?
    let build: String?
    let state: String?
    let deletable: Bool?
    let sizeBytes: UInt64?
    let lastUsedAt: String?
  }
}
