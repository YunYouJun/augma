import AppKit
import Combine
import Foundation

/// The versioned, credential-free configuration Magpie may edit. UserDefaults still
/// owns consent, the DSH executable and the successful connection-test fingerprint.
@MainActor
final class AssistantMagpieConfiguration: ObservableObject {
  static let shared = AssistantMagpieConfiguration()
  @Published private(set) var isManaged = false
  @Published private(set) var failure = ""
  let file: URL
  private let pluginOptionsFile: URL
  private let defaults: UserDefaults
  private var lastData: Data?
  private var effectiveEffort: String?
  private var activation: AnyCancellable?

  init(defaults: UserDefaults = .standard, file: URL? = nil, pluginOptionsFile: URL? = nil) {
    self.defaults = defaults
    self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Augma/Assistant/magpie.json")
    let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? ""
    let configDirectory = xdg.hasPrefix("/") ? URL(fileURLWithPath: xdg)
      : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
    self.pluginOptionsFile = pluginOptionsFile ?? configDirectory.appendingPathComponent("magpie/plugins.json")
  }

  func start() {
    refresh()
    activation = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in self?.refresh() }
  }

  /// Called on activation and before a request; no polling or external process is needed.
  func refresh() {
    do {
      if !FileManager.default.fileExists(atPath: file.path), lastData == nil {
        try write(["version": 1, "runtime": AssistantRuntimeSettings.backend(defaults).rawValue,
                   "model": defaults.string(forKey: AssistantRuntimeSettings.modelKey) ?? "",
                   "effort": defaults.string(forKey: AssistantRuntimeSettings.reasoningKey) ?? ""])
      }
      let data = try Data(contentsOf: file)
      let config = try Configuration.read(data)
      // Magpie's page bridge saves its own options, not the agent configuration.
      // Read only our integration's typed fields; never import provider credentials.
      let effort = config.managed == true && config.plugin == "magpie-plugin-augma"
        ? try readPluginEffort() : config.effort
      failure = ""
      isManaged = config.managed ?? false
      lastData = data
      effectiveEffort = effort
      let values = [(AssistantRuntimeSettings.backendKey, config.runtime),
                    (AssistantRuntimeSettings.modelKey, config.model),
                    (AssistantRuntimeSettings.reasoningKey, effort)]
      let changed = values.contains { key, value in
        key == AssistantRuntimeSettings.backendKey
          ? AssistantRuntimeSettings.backend(defaults).rawValue != value
          : (defaults.string(forKey: key) ?? "") != value
      }
      guard changed else { return }
      for (key, value) in values { defaults.set(value, forKey: key) }
      invalidate()
    } catch { reject() }
  }

  /// Preserve unknown fields and never overwrite a newer external selection.
  func saveLocal() {
    do {
      let data = try Data(contentsOf: file)
      let config = try Configuration.read(data)
      guard data == lastData else { refresh(); return }
      guard config.managed != true else { return }
      guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw AssistantRuntimeError.unsafeConfiguration
      }
      root["runtime"] = AssistantRuntimeSettings.backend(defaults).rawValue
      root["model"] = defaults.string(forKey: AssistantRuntimeSettings.modelKey) ?? ""
      root["effort"] = defaults.string(forKey: AssistantRuntimeSettings.reasoningKey) ?? ""
      try write(root)
      failure = ""
    } catch { reject() }
  }

  func hasModel(_ model: String) -> Bool {
    guard let lastData, let config = try? Configuration.read(lastData) else { return false }
    return config.model == model
  }

  func hasEffort(_ effort: String) -> Bool {
    effectiveEffort == effort
  }

  private func readPluginEffort() throws -> String {
    struct PluginList: Decodable {
      struct Entry: Decodable {
        struct Options: Decodable {
          let integration: String?
          let effort: String?
          enum CodingKeys: String, CodingKey { case integration, effort }
          init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            integration = try? values.decode(String.self, forKey: .integration)
            effort = try? values.decode(String.self, forKey: .effort)
          }
        }
        let off: Bool?
        let options: Options?
      }
      let plugins: [Entry]
    }
    let size = try pluginOptionsFile.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size <= 4_194_304 else { throw AssistantRuntimeError.unsafeConfiguration }
    let data = try Data(contentsOf: pluginOptionsFile)
    guard data.count <= 4_194_304 else { throw AssistantRuntimeError.unsafeConfiguration }
    let entries = try JSONDecoder().decode(PluginList.self, from: data).plugins
      .filter { $0.off != true && $0.options?.integration == "augma-v1" }
    guard entries.count == 1, let effort = entries[0].options?.effort,
          ["low", "medium", "high", "xhigh", "max"].contains(effort)
    else { throw AssistantRuntimeError.unsafeConfiguration }
    return effort
  }

  private func write(_ root: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    _ = try Configuration.read(data)
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                           attributes: [.posixPermissions: 0o700])
    try data.write(to: file, options: .atomic)
    lastData = data
    effectiveEffort = try Configuration.read(data).effort
  }

  private func invalidate() {
    defaults.set(false, forKey: AssistantRuntimeSettings.enabledKey)
    defaults.set("", forKey: AssistantRuntimeSettings.testedKey)
    AssistantRuntimeSettings.notifyChange()
  }

  private func reject() {
    failure = String(localized: "无法读取 Magpie 的 Augma 配置。请修复配置后重新检测；原文件未被覆盖。")
    invalidate()
  }

  private struct Configuration: Decodable {
    let version: Int
    let runtime: String
    let model: String
    let effort: String
    let managed: Bool?
    let plugin: String?

    static func read(_ data: Data) throws -> Self {
      guard data.count <= 65_536 else { throw AssistantRuntimeError.unsafeConfiguration }
      let value = try JSONDecoder().decode(Self.self, from: data)
      let efforts = ["", "none", "off", "minimal", "low", "medium", "high", "xhigh", "max"]
      guard value.version == 1, AssistantBackend(rawValue: value.runtime) != nil,
        value.model.count <= 512, !value.model.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
        value.model.isEmpty || (value.model.contains("/") && !value.model.contains(where: \.isWhitespace)),
        efforts.contains(value.effort), value.managed != true || (value.runtime == "dsh" && !value.model.isEmpty)
      else { throw AssistantRuntimeError.unsafeConfiguration }
      return value
    }
  }
}
