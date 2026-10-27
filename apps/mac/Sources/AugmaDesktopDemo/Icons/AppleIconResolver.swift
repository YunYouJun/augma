import AppKit
import UniformTypeIdentifiers

/// Resolves native artwork from app bundles and declared Apple device types, without shell processes.
@MainActor
final class AppleIconResolver {
  static let shared = AppleIconResolver()
  typealias TypeIdentifiers = @MainActor (String) -> [String]
  typealias ImageLoader = @MainActor (String) -> NSImage?

  private let typeIdentifiers: TypeIdentifiers
  private let image: ImageLoader
  private let applicationImage: ImageLoader
  private var cache: [AppleIconRequest: AppleIconResource] = [:]

  init(typeIdentifiers: @escaping TypeIdentifiers = { model in
    UTType.types(tag: model, tagClass: UTTagClass(rawValue: "com.apple.device-model-code"), conformingTo: nil)
      .filter { $0.isDeclared && $0.identifier.hasPrefix("com.apple.") }
      .map(\.identifier)
  }, image: @escaping ImageLoader = { identifier in
    guard let type = UTType(identifier), type.isDeclared, identifier.hasPrefix("com.apple.") else { return nil }
    return NSWorkspace.shared.icon(for: type)
  }, applicationImage: @escaping ImageLoader = { path in
    guard path.hasPrefix("/"), path.count <= 4_096,
          !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    var directory: ObjCBool = false
    guard url.pathExtension.lowercased() == "app",
          FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue,
          let bundle = Bundle(url: url),
          let packageType = bundle.infoDictionary?["CFBundlePackageType"] as? String,
          packageType == "APPL" || (packageType == "FNDR" && bundle.bundleIdentifier == "com.apple.finder")
    else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
  }) {
    self.typeIdentifiers = typeIdentifiers
    self.image = image
    self.applicationImage = applicationImage
  }

  /// Successful lookups and fallbacks are cached. Call invalidateCache after resource changes.
  /// Models with several color variants use deterministic type ordering, not an inferred device color.
  func resolve(_ request: AppleIconRequest) -> AppleIconResource {
    if let cached = cache[request] { return cached }
    let resource: AppleIconResource
    switch request {
    case .application(let bundlePath):
      resource = applicationImage(bundlePath).map(AppleIconResource.image) ?? .symbol("app")
    case .platform(let platform):
      resource = .platformLabel(platform.displayName)
    case .device(let modelIdentifier, let simulatorDeviceTypeIdentifier, let platform):
      let model = modelIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
      var artwork: NSImage?
      if let model, !model.isEmpty, model.count <= 128,
         !model.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
        for identifier in Set(typeIdentifiers(model)).sorted() {
          if let resolved = image(identifier) { artwork = resolved; break }
        }
      }
      resource = artwork.map(AppleIconResource.image)
        ?? .symbol(Self.fallback(model: model, simulatorType: simulatorDeviceTypeIdentifier, platform: platform))
    }
    // Bound long-lived UI caches without scheduling background work.
    if cache.count >= 256 { cache.removeAll(keepingCapacity: true) }
    cache[request] = resource
    return resource
  }

  func invalidateCache() { cache.removeAll(keepingCapacity: true) }

  private static func fallback(model: String?, simulatorType: String?, platform: ApplePlatform) -> String {
    if let model, let symbol = hardwareSymbol(model) { return symbol }
    if let simulatorType, let type = simulatorType.split(separator: ".").last,
       let symbol = hardwareSymbol(String(type)) { return symbol }
    switch platform {
    case .iOS: return "iphone.gen3"
    case .iPadOS: return "ipad"
    case .watchOS: return "applewatch"
    case .tvOS: return "appletv"
    case .visionOS: return "visionpro"
    case .macOS: return "desktopcomputer"
    case .unknown: return "rectangle"
    }
  }

  private static func hardwareSymbol(_ identifier: String) -> String? {
    let identifier = identifier.lowercased()
    if identifier.hasPrefix("iphone") { return "iphone.gen3" }
    if identifier.hasPrefix("ipad") { return "ipad" }
    if identifier.hasPrefix("watch") || identifier.hasPrefix("apple-watch") { return "applewatch" }
    if identifier.hasPrefix("appletv") || identifier.hasPrefix("apple-tv") { return "appletv" }
    if identifier.hasPrefix("realitydevice") || identifier.hasPrefix("apple-vision") { return "visionpro" }
    if identifier.hasPrefix("macbook") { return "laptopcomputer" }
    if identifier.hasPrefix("mac") || identifier.hasPrefix("imac") { return "desktopcomputer" }
    return nil
  }
}
