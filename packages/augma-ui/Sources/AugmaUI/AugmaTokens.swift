// Generated from packages/core/src/tokens.json by scripts/sync-tokens.mjs. Do not edit by hand.
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct AugmaRGB: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double

  public init(_ red: Double, _ green: Double, _ blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

public enum AugmaPalette {
  public static let highlight = (light: AugmaRGB(242, 140, 18), dark: AugmaRGB(242, 140, 18))
  public static let accent = (light: AugmaRGB(183, 94, 8), dark: AugmaRGB(241, 167, 76))
  public static let cyan = (light: AugmaRGB(37, 140, 164), dark: AugmaRGB(103, 200, 218))
  public static let success = (light: AugmaRGB(40, 121, 71), dark: AugmaRGB(124, 218, 160))
  public static let danger = (light: AugmaRGB(188, 57, 74), dark: AugmaRGB(255, 149, 164))
  public static let upload = (light: AugmaRGB(30, 100, 192), dark: AugmaRGB(112, 175, 255))

  public static var healthy: (light: AugmaRGB, dark: AugmaRGB) { success }
  public static var critical: (light: AugmaRGB, dark: AugmaRGB) { danger }
}

public enum AugmaMotion {
  public static let durationMs: Int = 160
  public static let durationSlowMs: Int = 420
  public static let duration: Double = 0.16
  public static let durationSlow: Double = 0.42
  public static let ease: (Double, Double, Double, Double) = (0.16, 1, 0.3, 1)
  public static let easeIn: (Double, Double, Double, Double) = (0.7, 0, 0.84, 0)
  public static let easeSpring: (Double, Double, Double, Double) = (0.34, 1.56, 0.64, 1)
}

public extension Color {
  /// Decorative HUD light (`--agm-highlight`), identical in both appearances.
  static let augmaHighlight = Color(augma: AugmaPalette.highlight)
  /// Action color (`--agm-accent`).
  static let augmaAccent = Color(augma: AugmaPalette.accent)
  /// Continuous controls and healthy state (`--agm-cyan`).
  static let augmaCyan = Color(augma: AugmaPalette.cyan)
  /// Semantic success / healthy status (`--agm-success`).
  static let augmaHealthy = Color(augma: AugmaPalette.success)
  /// Semantic danger / critical status (`--agm-danger`).
  static let augmaCritical = Color(augma: AugmaPalette.danger)
  /// Traffic direction is categorical; keep upload blue so orange retains its warning meaning.
  static let augmaUpload = Color(augma: AugmaPalette.upload)

  private init(augma pair: (light: AugmaRGB, dark: AugmaRGB)) {
    #if canImport(AppKit)
    self.init(nsColor: NSColor(name: nil) { appearance in
      let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? pair.dark : pair.light
      return NSColor(srgbRed: rgb.red / 255, green: rgb.green / 255, blue: rgb.blue / 255, alpha: 1)
    })
    #elseif canImport(UIKit)
    self.init(uiColor: UIColor { traits in
      let rgb = traits.userInterfaceStyle == .dark ? pair.dark : pair.light
      return UIColor(red: rgb.red / 255, green: rgb.green / 255, blue: rgb.blue / 255, alpha: 1)
    })
    #else
    self.init(red: pair.light.red / 255, green: pair.light.green / 255, blue: pair.light.blue / 255)
    #endif
  }
}

/// Matches `--agm-ease`: arrive fast, settle softly.
public extension Animation {
  static func augma(duration: Double = AugmaMotion.durationSlow) -> Animation {
    let (c1x, c1y, c2x, c2y) = AugmaMotion.ease
    return .timingCurve(c1x, c1y, c2x, c2y, duration: duration)
  }
}
