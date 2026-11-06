import AppKit
import Combine
import Foundation

struct AugmaPluginShortcut: Codable, Hashable {
  let id: String
  let name: String
  let symbol: String
  var localizations: [String: AugmaPluginMetadata]? = nil
}

enum NativeDockItem: RawRepresentable, CaseIterable, Hashable, Identifiable {
  case mirror, weather, hud, audio, space, camera, navigation, market, library, browser, github, docs
  case feature(DemoModule)
  case application(InstalledApplication)
  case plugin(AugmaPluginShortcut)

  static let allCases: [Self] = [.mirror, .weather, .hud, .audio, .space, .camera, .navigation, .market, .library, .browser, .github, .docs]

  init(module: DemoModule) {
    self = Self.allCases.first { $0.module == module } ?? .feature(module)
  }

  init?(rawValue: String) {
    if let builtin = Self.allCases.first(where: { $0.rawValue == rawValue }) { self = builtin; return }
    if let module = DemoModule(rawValue: rawValue) { self = .feature(module); return }
    if rawValue.hasPrefix("plugin:"), rawValue.count < 8192,
       let data = Data(base64Encoded: String(rawValue.dropFirst("plugin:".count))),
       let plugin = try? JSONDecoder().decode(AugmaPluginShortcut.self, from: data),
       AugmaPluginManifest.validID(plugin.id), !plugin.name.isEmpty, plugin.name.count <= 60,
       !plugin.symbol.isEmpty, plugin.symbol.count <= 80, AugmaPluginManifest.validLocalizations(plugin.localizations) {
      self = .plugin(plugin); return
    }
    guard rawValue.hasPrefix("application:"), rawValue.count <= 16384,
          let data = Data(base64Encoded: String(rawValue.dropFirst("application:".count))),
          let app = try? JSONDecoder().decode(InstalledApplication.self, from: data),
          !app.id.isEmpty, app.id.count <= 255, !app.id.contains(where: { $0.isWhitespace || $0.isNewline }),
          !app.name.isEmpty, app.name.count <= 80, app.path.hasPrefix("/"), app.path.count <= 4096,
          URL(fileURLWithPath: app.path).pathExtension.lowercased() == "app" else { return nil }
    self = .application(app)
  }

  var rawValue: String {
    switch self {
    case .mirror: "mirror"
    case .weather: "weather"
    case .hud: "hud"
    case .audio: "audio"
    case .space: "space"
    case .camera: "camera"
    case .navigation: "navigation"
    case .market: "market"
    case .library: "library"
    case .browser: "browser"
    case .github: "github"
    case .docs: "docs"
    case .feature(let module): module.rawValue
    case .application(let app): Self.encode(app)
    case .plugin(let plugin): Self.encode(plugin)
    }
  }

  private static func encode(_ app: InstalledApplication) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return "application:" + ((try? encoder.encode(app))?.base64EncodedString() ?? "")
  }

  private static func encode(_ plugin: AugmaPluginShortcut) -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
    return "plugin:" + ((try? encoder.encode(plugin))?.base64EncodedString() ?? "")
  }

  var id: String {
    switch self {
    case .application(let app): "application:" + app.id
    case .plugin(let plugin): "plugin:" + plugin.id
    default: rawValue
    }
  }
  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.application == rhs.application && lhs.plugin == rhs.plugin }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(application)
    hasher.combine(plugin)
  }
  var module: DemoModule? { if case .application = self { nil } else { DemoModule(rawValue: rawValue) } }
  var application: InstalledApplication? { if case .application(let app) = self { app } else { nil } }
  var plugin: AugmaPluginShortcut? { if case .plugin(let plugin) = self { plugin } else { nil } }
  var title: String {
    switch self {
    case .mirror: String(appLocalized: "镜像视图")
    case .hud: "HUD"
    case .github: "GitHub"
    case .docs: String(appLocalized: "Augma 文档")
    case .application(let app): app.name
    case .plugin(let plugin): plugin.localizations?[NativeLocalization.language]?.name ?? plugin.name
    default: module?.title ?? rawValue
    }
  }
}

/// The main window and immersive panels share one layout. Drag previews never write preferences.
@MainActor
final class NativeDockStore: ObservableObject {
  static let storageKey = "augma.dock.items.v1"
  @Published private(set) var items: [NativeDockItem]
  @Published private(set) var draggedItem: NativeDockItem?
  @Published private(set) var previewItems: [NativeDockItem]?
  @Published var launchError = ""
  var onOpen: ((String) -> Void)?
  private let defaults: UserDefaults
  private let client: any InstalledApplicationClient
  private var opening = Set<String>()

  init(defaults: UserDefaults = .standard, client: any InstalledApplicationClient = SystemInstalledApplicationClient()) {
    self.defaults = defaults
    self.client = client
    if let saved = defaults.stringArray(forKey: Self.storageKey) {
      var seen = Set<String>()
      items = saved.compactMap(NativeDockItem.init(rawValue:)).filter { seen.insert($0.id).inserted }
    } else {
      items = NativeDockItem.allCases
    }
  }

  var displayedItems: [NativeDockItem] { previewItems ?? items }
  var removedItems: [NativeDockItem] { NativeDockItem.allCases.filter { !items.contains($0) } }
  func contains(_ application: InstalledApplication) -> Bool { items.contains { $0.application?.id == application.id } }

  func resolvedApplication(for item: NativeDockItem) -> InstalledApplication? {
    guard let app = item.application else { return nil }
    return client.resolve(.init(id: app.id, applicationName: app.name, applicationPath: app.path, slot: 0))
  }

  func open(_ item: NativeDockItem) async {
    guard let saved = item.application, opening.insert(saved.id).inserted else { return }
    defer { opening.remove(saved.id) }
    do {
      guard let application = resolvedApplication(for: item) else { throw ApplicationDistrictError.missingApplication }
      try await client.open(application)
      launchError = ""
      onOpen?(application.id)
    } catch { launchError = error.localizedDescription }
  }

  func remove(_ item: NativeDockItem) {
    cancelDrag()
    save(items.filter { $0.id != item.id })
  }

  func restore(_ item: NativeDockItem) {
    cancelDrag()
    if let index = items.firstIndex(where: { $0.id == item.id }) {
      var next = items; next[index] = item; save(next); return
    }
    save(items + [item])
  }

  func reset() {
    cancelDrag()
    save(NativeDockItem.allCases)
  }

  func move(_ item: NativeDockItem, by offset: Int) {
    guard let index = items.firstIndex(of: item), items.indices.contains(index + offset) else { return }
    cancelDrag()
    var next = items
    next.remove(at: index)
    next.insert(item, at: index + offset)
    save(next)
  }

  func beginDrag(_ item: NativeDockItem) {
    guard items.contains(item) else { return }
    draggedItem = item
    previewItems = items
  }

  func previewMove(over target: NativeDockItem) {
    guard let draggedItem, var next = previewItems,
          let source = next.firstIndex(of: draggedItem), let destination = next.firstIndex(of: target),
          source != destination else { return }
    next.remove(at: source)
    next.insert(draggedItem, at: destination)
    previewItems = next
  }

  @discardableResult
  func commitDrop() -> Bool {
    guard draggedItem != nil, let previewItems else { return false }
    save(previewItems)
    cancelDrag()
    return true
  }

  func cancelDrag() {
    draggedItem = nil
    previewItems = nil
  }

  private func save(_ next: [NativeDockItem]) {
    guard items != next else { return }
    items = next
    defaults.set(next.map(\.rawValue), forKey: Self.storageKey)
  }
}
