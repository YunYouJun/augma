import Foundation
import SwiftUI
import XCTest
@testable import AugmaUI

final class AugmaUITests: XCTestCase {
  func testPaletteMatchesSharedTokensJSON() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let tokensURL = packageRoot
      .deletingLastPathComponent()
      .appendingPathComponent("core/src/tokens.json")
    let data = try Data(contentsOf: tokensURL)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let colors = try XCTUnwrap(json["colors"] as? [String: Any])

    func rgb(_ key: String, _ mode: String) throws -> AugmaRGB {
      let entry = try XCTUnwrap(colors[key] as? [String: Any])
      let rgbMap = try XCTUnwrap(entry["rgb"] as? [String: Any])
      let values = try XCTUnwrap(rgbMap[mode] as? [Double])
      XCTAssertEqual(values.count, 3)
      return AugmaRGB(values[0], values[1], values[2])
    }

    XCTAssertEqual(AugmaPalette.accent.light, try rgb("accent", "light"))
    XCTAssertEqual(AugmaPalette.accent.dark, try rgb("accent", "dark"))
    XCTAssertEqual(AugmaPalette.highlight.light, try rgb("highlight", "light"))
    XCTAssertEqual(AugmaPalette.highlight.dark, try rgb("highlight", "dark"))
    XCTAssertEqual(AugmaPalette.cyan.light, try rgb("cyan", "light"))
    XCTAssertEqual(AugmaPalette.cyan.dark, try rgb("cyan", "dark"))
    XCTAssertEqual(AugmaPalette.success.light, try rgb("success", "light"))
    XCTAssertEqual(AugmaPalette.success.dark, try rgb("success", "dark"))
    XCTAssertEqual(AugmaPalette.healthy.light, try rgb("success", "light"))
    XCTAssertEqual(AugmaPalette.healthy.dark, try rgb("success", "dark"))
    XCTAssertEqual(AugmaPalette.danger.light, try rgb("danger", "light"))
    XCTAssertEqual(AugmaPalette.danger.dark, try rgb("danger", "dark"))
    XCTAssertEqual(AugmaPalette.critical.light, try rgb("danger", "light"))
    XCTAssertEqual(AugmaPalette.critical.dark, try rgb("danger", "dark"))
    XCTAssertEqual(AugmaPalette.upload.light, try rgb("upload", "light"))
    XCTAssertEqual(AugmaPalette.upload.dark, try rgb("upload", "dark"))
  }

  func testButtonRolesEnumCoversAllSemanticRoles() {
    XCTAssertEqual(AugmaButtonRole.allCases, [.primary, .secondary, .floating, .floatingProminent])
  }

  func testHudBracketsBuildsNonEmptyPath() {
    let path = HudBrackets().path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
    XCTAssertFalse(path.isEmpty)
  }

  @MainActor
  func testViewsAndModifiersConstructCleanly() {
    let orb = AugmaGlassOrbButton(title: "Settings", symbol: "gearshape", badge: 3) {}
    let label = AugmaOrbLabel(symbol: "command", tint: .augmaCyan, selected: true)
    let ring = AugmaRing(size: 64, spinning: false)
    let ping = StatusPing(color: .augmaHealthy, active: false)
    let bar = AugmaGlassActionBar {
      Button("Primary") {}.augmaButton(.primary)
      Button("Secondary") {}.augmaButton(.secondary)
      Button("Floating") {}.augmaButton(.floating)
      Button("Prominent") {}.augmaButton(.floatingProminent)
    }
    let materialized = VStack {
      orb
      label
      ring
      ping
      bar
    }
    .augmaGlass(cornerRadius: 20, interactive: true)
    .augmaGlassCapsule(clear: true)
    .augmaMaterialize(active: true)

    let mirror = Mirror(reflecting: materialized)
    XCTAssertGreaterThan(mirror.children.count, 0)
  }
}
