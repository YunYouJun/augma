import AppKit
import Combine

/// A bounded display-only export. No account sessions, executable paths or actions are accepted from the file.
struct CraftHubTodaySummary: Decodable, Equatable {
  struct Item: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
  }
  let version: Int
  let checkedAt: String
  let total: Int
  let sourceCount: Int
  let loadedSourceCount: Int
  let completeSourceCount: Int
  let items: [Item]

  var date: Date? {
    let format = ISO8601DateFormatter()
    format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return format.date(from: checkedAt) ?? ISO8601DateFormatter().date(from: checkedAt)
  }

  static func read(_ url: URL) throws -> Self {
    guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
      throw CompanionError.invalidSummary
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    guard let bytes = try handle.read(upToCount: 64 * 1024 + 1), bytes.count <= 64 * 1024 else {
      throw CompanionError.invalidSummary
    }
    let result = try JSONDecoder().decode(Self.self, from: bytes)
    guard result.version == 1, let date = result.date, date.timeIntervalSinceNow <= 300,
      date.timeIntervalSince1970 > 0, (0...1_000_000).contains(result.total),
      (0...10_000).contains(result.sourceCount), (0...result.sourceCount).contains(result.loadedSourceCount),
      (0...result.loadedSourceCount).contains(result.completeSourceCount),
      result.items.count <= 5, result.items.count <= result.total,
      Set(result.items.map(\.id)).count == result.items.count,
      result.items.allSatisfy({
        !$0.id.isEmpty && $0.id.count <= 128 && !$0.title.isEmpty && $0.title.count <= 1000
          && $0.sourceTitle.count <= 300
      })
    else { throw CompanionError.invalidSummary }
    return result
  }
}

enum CompanionError: LocalizedError {
  case invalidSummary, missingApplication
  var errorDescription: String? {
    switch self {
    case .invalidSummary: String(localized: "摘要格式不兼容，请在 Craft Hub 重新共享今日重点。")
    case .missingApplication: String(localized: "请选择 Craft Hub 的 Electron 应用。原生候选版不会作为主界面启动。")
    }
  }
}

/// Uses the existing Augma process and draft owner. It never launches a sidecar or opens a Craft Hub profile.
@MainActor
final class CraftHubCompanionStore: ObservableObject {
  @Published private(set) var summary: CraftHubTodaySummary?
  @Published private(set) var error: String?
  @Published private(set) var summaryPath: String?
  @Published private(set) var applicationPath: String?
  private let defaults: UserDefaults
  private let reader: (URL) throws -> CraftHubTodaySummary
  private let open: (URL) async throws -> Void

  init(
    defaults: UserDefaults = .standard,
    reader: @escaping (URL) throws -> CraftHubTodaySummary = CraftHubTodaySummary.read,
    open: ((URL) async throws -> Void)? = nil
  ) {
    self.defaults = defaults
    self.reader = reader
    self.open =
      open ?? { url in
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
      }
    summaryPath = defaults.string(forKey: "craftHub.companion.summaryPath.v1")
    applicationPath = defaults.string(forKey: "craftHub.companion.applicationPath.v1")
    refresh()
  }

  func selectSummary(_ url: URL) {
    do {
      let value = try reader(url)
      summary = value
      summaryPath = url.path
      defaults.set(url.path, forKey: "craftHub.companion.summaryPath.v1")
      error = nil
    } catch { self.error = String(localized: "无法读取所选摘要。原有连接和缓存已保留，请重新选择。") }
  }

  func refresh() {
    guard let summaryPath else { return }
    do {
      summary = try reader(URL(fileURLWithPath: summaryPath))
      error = nil
    } catch { self.error = String(localized: "摘要暂不可读。保留上次缓存；请在 Craft Hub 检查共享文件。") }
  }

  func disconnect() {
    summary = nil
    summaryPath = nil
    error = nil
    defaults.removeObject(forKey: "craftHub.companion.summaryPath.v1")
  }

  func selectApplication(_ url: URL) {
    guard Self.isElectronApplication(url) else {
      error = CompanionError.missingApplication.localizedDescription
      return
    }
    applicationPath = url.path
    defaults.set(url.path, forKey: "craftHub.companion.applicationPath.v1")
    error = nil
  }

  func openMain() async {
    let url =
      applicationPath.map { URL(fileURLWithPath: $0) }
      ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.yunyoujun.craft-hub")
    guard let url, Self.isElectronApplication(url) else {
      error = CompanionError.missingApplication.localizedDescription
      return
    }
    do {
      try await open(url)
      error = nil
    } catch { self.error = String(localized: "无法打开 Craft Hub，请检查应用位置后重试。") }
  }

  private static func isElectronApplication(_ url: URL) -> Bool {
    url.isFileURL && url.pathExtension == "app" && Bundle(url: url)?.executableURL != nil
      && FileManager.default.fileExists(
        atPath: url.appending(path: "Contents/Frameworks/Electron Framework.framework").path)
  }
}
