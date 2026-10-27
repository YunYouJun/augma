import AppKit

/// Stable identities only: a user-editable device name is never an icon lookup key.
enum AppleIconRequest: Hashable {
  case application(bundlePath: String)
  case device(modelIdentifier: String? = nil, simulatorDeviceTypeIdentifier: String? = nil,
              platform: ApplePlatform = .unknown)
  case platform(ApplePlatform)
}

enum ApplePlatform: String, CaseIterable {
  case iOS, iPadOS, watchOS, tvOS, visionOS, macOS, unknown

  init(runtimeIdentifier: String) {
    let token = runtimeIdentifier.split(separator: ".").last?.split(separator: "-").first.map(String.init) ?? ""
    switch token.lowercased() {
    case "ios", "iphoneos": self = .iOS
    case "ipados": self = .iPadOS
    case "watchos": self = .watchOS
    case "tvos": self = .tvOS
    case "visionos", "xros": self = .visionOS
    case "macos", "macosx": self = .macOS
    default: self = .unknown
    }
  }

  var displayName: String { self == .unknown ? "OS" : rawValue }
}

/// Keeps resolution usable from both AppKit and SwiftUI without exposing system lookup details.
enum AppleIconResource {
  case image(NSImage)
  case symbol(String)
  case platformLabel(String)
}
