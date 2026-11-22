import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function cubicBezier(points) {
  return `cubic-bezier(${points.join(', ')})`
}

function formatCssDeclaration(name, value) {
  const inline = `  ${name}: ${value};`
  if (inline.length <= 80 || !value.includes(', '))
    return inline
  return `  ${name}:\n    ${value};`
}

function renderTokensCss(tokens) {
  const lightLines = [
    formatCssDeclaration('--agm-font', tokens.font),
  ]
  const darkLines = []
  for (const entry of Object.values(tokens.colors)) {
    if (!entry.css)
      continue
    lightLines.push(formatCssDeclaration(entry.css, entry.light))
    if (entry.dark && entry.dark !== entry.light)
      darkLines.push(formatCssDeclaration(entry.css, entry.dark))
  }
  lightLines.push(
    formatCssDeclaration('--agm-cut', tokens.cut),
    formatCssDeclaration('--agm-glass-blur', tokens.glassBlur),
    '  /* Motion: HUD elements arrive fast and settle softly; exits are short. */',
    formatCssDeclaration('--agm-duration', `${tokens.motion.durationMs}ms`),
    formatCssDeclaration('--agm-duration-slow', `${tokens.motion.durationSlowMs}ms`),
    formatCssDeclaration('--agm-ease', cubicBezier(tokens.motion.ease)),
    formatCssDeclaration('--agm-ease-in', cubicBezier(tokens.motion.easeIn)),
    formatCssDeclaration('--agm-ease-spring', cubicBezier(tokens.motion.easeSpring)),
  )

  return [
    '/* Generated from packages/core/src/tokens.json by scripts/sync-tokens.mjs. */',
    ':root,',
    '[data-agm-theme=\'light\'] {',
    ...lightLines,
    '}',
    '.dark,',
    '[data-agm-theme=\'dark\'] {',
    ...darkLines,
    '}',
    '',
  ].join('\n')
}

function rgbLiteral(triple) {
  return `AugmaRGB(${triple[0]}, ${triple[1]}, ${triple[2]})`
}

function renderTokensSwift(tokens) {
  const { colors, motion } = tokens
  const swiftColors = [
    ['highlight', colors.highlight.rgb],
    ['accent', colors.accent.rgb],
    ['cyan', colors.cyan.rgb],
    ['success', colors.success.rgb],
    ['danger', colors.danger.rgb],
    ['upload', colors.upload.rgb],
  ]
  const paletteLines = swiftColors.map(
    ([name, rgb]) => `  public static let ${name} = (light: ${rgbLiteral(rgb.light)}, dark: ${rgbLiteral(rgb.dark)})`,
  )
  const ease = motion.ease
  const easeIn = motion.easeIn
  const easeSpring = motion.easeSpring

  return `// Generated from packages/core/src/tokens.json by scripts/sync-tokens.mjs. Do not edit by hand.
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
${paletteLines.join('\n')}

  public static var healthy: (light: AugmaRGB, dark: AugmaRGB) { success }
  public static var critical: (light: AugmaRGB, dark: AugmaRGB) { danger }
}

public enum AugmaMotion {
  public static let durationMs: Int = ${motion.durationMs}
  public static let durationSlowMs: Int = ${motion.durationSlowMs}
  public static let duration: Double = ${motion.durationMs / 1000}
  public static let durationSlow: Double = ${motion.durationSlowMs / 1000}
  public static let ease: (Double, Double, Double, Double) = (${ease.join(', ')})
  public static let easeIn: (Double, Double, Double, Double) = (${easeIn.join(', ')})
  public static let easeSpring: (Double, Double, Double, Double) = (${easeSpring.join(', ')})
}

public extension Color {
  /// Decorative HUD light (\`--agm-highlight\`), identical in both appearances.
  static let augmaHighlight = Color(augma: AugmaPalette.highlight)
  /// Action color (\`--agm-accent\`).
  static let augmaAccent = Color(augma: AugmaPalette.accent)
  /// Continuous controls and healthy state (\`--agm-cyan\`).
  static let augmaCyan = Color(augma: AugmaPalette.cyan)
  /// Semantic success / healthy status (\`--agm-success\`).
  static let augmaHealthy = Color(augma: AugmaPalette.success)
  /// Semantic danger / critical status (\`--agm-danger\`).
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

/// Matches \`--agm-ease\`: arrive fast, settle softly.
public extension Animation {
  static func augma(duration: Double = AugmaMotion.durationSlow) -> Animation {
    let (c1x, c1y, c2x, c2y) = AugmaMotion.ease
    return .timingCurve(c1x, c1y, c2x, c2y, duration: duration)
  }
}
`
}

export async function syncTokens(projectRoot = root) {
  const tokens = JSON.parse(await readFile(resolve(projectRoot, 'packages/core/src/tokens.json'), 'utf8'))
  const cssPath = resolve(projectRoot, 'packages/core/src/tokens.css')
  const swiftPath = resolve(projectRoot, 'packages/augma-ui/Sources/AugmaUI/AugmaTokens.swift')
  await mkdir(dirname(cssPath), { recursive: true })
  await mkdir(dirname(swiftPath), { recursive: true })
  await writeFile(cssPath, renderTokensCss(tokens))
  await writeFile(swiftPath, renderTokensSwift(tokens))
  return { cssPath, swiftPath }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  await syncTokens()
  console.log('Synced design tokens to packages/core/src/tokens.css and packages/augma-ui/Sources/AugmaUI/AugmaTokens.swift')
}
