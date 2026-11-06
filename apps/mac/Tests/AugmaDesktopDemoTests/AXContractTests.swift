import Foundation
import XCTest

/// Contract tests for the native accessibility identifiers.
///
/// The live AX tree is not available to `swift test`: reading it requires a
/// trusted accessibility process and a running App. These tests therefore
/// verify the versioned contract, its coverage of the Swift sources, and the
/// declared state of each identifier. Real AX-tree operation was exercised in
/// apps/mac/docs/disk-usage-acceptance.md; VoiceOver announcement is not claimed.
final class AXContractTests: XCTestCase {
  private struct Contract: Decodable {
    let schemaVersion: Int
    let app: String
    let platform: String
    let identifierAttribute: String
    let description: String
    let reviewPolicy: String
    let scenes: [String: String]
    let roles: [String]
    let actions: [String]
    let accessLevels: [String]
    let runtimeVerification: RuntimeVerification
    let elements: [Element]
  }

  private struct RuntimeVerification: Decodable {
    let axTreeOperatedInAcceptance: Bool
    let acceptanceEvidence: String
    let requiresTrustedAccessibilityProcess: Bool
    let voiceOverAnnouncementVerified: Bool
    let unitTestReadsAXTree: Bool
    let note: String
  }

  private struct Element: Decodable {
    let id: String?
    let pattern: String?
    let role: String
    let label: String?
    let scene: String
    let actions: [String]
    let access: String
    let preconditions: [String]
    let disabledWhen: String?
    let idempotent: Bool
    let reviewed: Bool
    let declaredVia: String
    let source: String
    let notes: String

    var key: String { id ?? pattern ?? "" }
  }

  private struct Inventory: Decodable {
    let schemaVersion: Int
    let elements: [InventoryElement]
  }

  private struct InventoryElement: Decodable {
    let id: String?
    let pattern: String?
    let source: String
    var key: String { id ?? pattern ?? "" }
  }

  private static let writeActions: Set<String> = ["press", "setValue", "select"]

  /// Walk up from this file until the repo root is found. The package can be
  /// tested from any working directory, so #filePath is the stable anchor.
  private var repoRoot: URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for _ in 0..<8 {
      if FileManager.default.fileExists(atPath: url.appendingPathComponent("apps/mac/Package.swift").path) { return url }
      url.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  }

  private func load<T: Decodable>(_ path: String, as type: T.Type) throws -> T {
    let data = try Data(contentsOf: repoRoot.appendingPathComponent(path))
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func loadContract() throws -> Contract {
    try load("apps/mac/docs/ax-contract.json", as: Contract.self)
  }

  private func loadInventory() throws -> Inventory {
    try load("apps/mac/docs/ax-identifiers.json", as: Inventory.self)
  }

  // MARK: - Source extraction (mirrors scripts/generate-ax-contract.mjs)

  private func argument(of text: String, from open: String.Index) -> String {
    var depth = 0
    var inString = false
    var escaped = false
    var index = open
    while index < text.endIndex {
      let char = text[index]
      if inString {
        if escaped { escaped = false }
        else if char == "\\" { escaped = true }
        else if char == "\"" { inString = false }
      } else if char == "\"" {
        inString = true
      } else if char == "(" {
        depth += 1
      } else if char == ")" {
        depth -= 1
        if depth == 0 { return String(text[text.index(after: open)..<index]) }
      }
      index = text.index(after: index)
    }
    return ""
  }

  private func stringLiterals(in text: String) -> [String] {
    var result: [String] = []
    var index = text.startIndex
    while index < text.endIndex {
      guard text[index] == "\"" else {
        index = text.index(after: index)
        continue
      }
      var value = ""
      var escaped = false
      index = text.index(after: index)
      while index < text.endIndex {
        let char = text[index]
        if escaped {
          value.append(char)
          escaped = false
        } else if char == "\\" {
          escaped = true
        } else if char == "\"" {
          break
        } else {
          value.append(char)
        }
        index = text.index(after: index)
      }
      if index < text.endIndex {
        result.append(value)
        index = text.index(after: index)
      }
    }
    return result
  }

  private struct SourceScan {
    var ids = Set<String>()
    var patterns = Set<String>()
    var fileCount = 0
    var dockComputed = false
    var keys: Set<String> { ids.union(patterns) }
  }

  private func scanSources() throws -> SourceScan {
    let root = repoRoot.appendingPathComponent("apps/mac/Sources")
    let enumerator = try XCTUnwrap(FileManager.default.enumerator(
      at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]))
    var files: [URL] = []
    while let object = enumerator.nextObject() {
      guard let url = object as? URL, url.pathExtension == "swift" else { continue }
      files.append(url)
    }
    files.sort { $0.path < $1.path }

    var scan = SourceScan()
    scan.fileCount = files.count
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      var range = text.startIndex..<text.endIndex
      while let match = text.range(of: ".accessibilityIdentifier(", range: range) {
        let open = text.index(before: match.upperBound)
        let expression = argument(of: text, from: open)
        let literals = stringLiterals(in: expression)
        if !literals.isEmpty {
          if expression.contains("+") { scan.patterns.insert(literals[0] + "{id}") }
          else { scan.ids.formUnion(literals) }
        }
        range = match.upperBound..<text.endIndex
      }

      // NativeOrbButton forwards identifier: to .accessibilityIdentifier(identifier).
      if text.contains("NativeOrbButton(") {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
          guard let marker = line.range(of: "identifier:") else { continue }
          scan.ids.formUnion(stringLiterals(in: String(line[marker.upperBound...])))
        }
      }

      if file.lastPathComponent == "ImmersiveDockView.swift",
         text.contains("identifier(for:"), text.contains("\"immersive-\"") {
        scan.dockComputed = true
      }
    }
    if scan.dockComputed {
      scan.patterns.insert("immersive-dock-{id}")
      scan.patterns.insert("immersive-{id}")
    }
    return scan
  }

  /// Resolve a concrete id or a dynamic id produced by a `{id}` pattern.
  /// Prefer the longest literal prefix so `immersive-dock-weather` resolves to
  /// `immersive-dock-{id}` rather than the broader `immersive-{id}`.
  private func element(_ contract: Contract, for key: String) throws -> Element {
    if let exact = contract.elements.first(where: { $0.id == key }) { return exact }
    let candidates = contract.elements.compactMap { element -> (Int, Element)? in
      guard let pattern = element.pattern else { return nil }
      let parts = pattern.components(separatedBy: "{id}")
      guard parts.count == 2,
            key.hasPrefix(parts[0]), key.hasSuffix(parts[1]),
            key.count > parts[0].count + parts[1].count else { return nil }
      return (parts[0].count, element)
    }
    return try XCTUnwrap(candidates.max(by: { $0.0 < $1.0 })?.1, "No contract element for \(key)")
  }

  // MARK: - Tests

  func testRepoLayoutIsResolvable() {
    XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("apps/mac/Package.swift").path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("apps/mac/docs/ax-contract.json").path))
  }

  func testContractSchemaIsValid() throws {
    let contract = try loadContract()
    XCTAssertEqual(contract.schemaVersion, 1)
    XCTAssertEqual(contract.app, "AugmaDesktopDemo")
    XCTAssertEqual(contract.identifierAttribute, "AXIdentifier")
    XCTAssertFalse(contract.description.isEmpty)
    XCTAssertFalse(contract.reviewPolicy.isEmpty)
    XCTAssertFalse(contract.scenes.isEmpty)
    for role in ["button", "staticText", "textField", "checkBox", "popUpButton", "slider",
                 "progressIndicator", "menuButton", "group", "list", "unknown"] {
      XCTAssertTrue(contract.roles.contains(role), "missing role \(role)")
    }
    for action in ["press", "setValue", "readValue", "select", "focus"] {
      XCTAssertTrue(contract.actions.contains(action), "missing action \(action)")
    }
    XCTAssertEqual(Set(contract.accessLevels), Set(["read", "write"]))

    var keys = Set<String>()
    let sources = repoRoot.appendingPathComponent("apps/mac/Sources")
    for element in contract.elements {
      XCTAssertFalse(element.key.isEmpty)
      XCTAssertTrue((element.id == nil) != (element.pattern == nil), "\(element.key) needs exactly one of id/pattern")
      XCTAssertTrue(keys.insert(element.key).inserted, "duplicate identifier \(element.key)")
      XCTAssertTrue(contract.roles.contains(element.role), "\(element.key): invalid role \(element.role)")
      XCTAssertNotNil(contract.scenes[element.scene], "\(element.key): unknown scene \(element.scene)")
      XCTAssertFalse(element.actions.isEmpty, "\(element.key): actions required")
      for action in element.actions {
        XCTAssertTrue(contract.actions.contains(action), "\(element.key): invalid action \(action)")
      }
      XCTAssertTrue(contract.accessLevels.contains(element.access), "\(element.key): invalid access \(element.access)")
      if element.actions.contains(where: { Self.writeActions.contains($0) }) {
        XCTAssertEqual(element.access, "write", "\(element.key): write actions require access=write")
      }
      if element.access == "read" {
        XCTAssertFalse(element.actions.contains(where: { Self.writeActions.contains($0) }),
                       "\(element.key): read-only element cannot have write actions")
      }
      XCTAssertFalse(element.declaredVia.isEmpty)
      XCTAssertTrue(FileManager.default.fileExists(atPath: sources.appendingPathComponent(element.source).path),
                    "\(element.key): source file \(element.source) is missing")
    }
  }

  func testContractMatchesSwiftSourcesAndInventory() throws {
    let contract = try loadContract()
    let inventory = try loadInventory()
    let scan = try scanSources()

    XCTAssertEqual(inventory.schemaVersion, 1)
    XCTAssertGreaterThan(scan.fileCount, 100)
    XCTAssertTrue(scan.dockComputed, "Computed dock identifier expression changed")

    let contractKeys = Set(contract.elements.map(\.key))
    let inventoryKeys = Set(inventory.elements.map(\.key))
    XCTAssertEqual(contractKeys, inventoryKeys, "Contract and inventory disagree")
    XCTAssertEqual(inventoryKeys, scan.keys, "Swift sources drifted; run node scripts/generate-ax-contract.mjs --write")

    for element in contract.elements {
      let match = inventory.elements.first { $0.key == element.key }
      XCTAssertEqual(element.source, match?.source, "\(element.key): source file drifted")
    }
  }

  func testEverySceneHasAtLeastOneDeclaredElement() throws {
    let contract = try loadContract()
    for scene in contract.scenes.keys {
      XCTAssertTrue(contract.elements.contains { $0.scene == scene }, "scene \(scene) has no AX identifiers")
    }
  }

  func testRuntimeVerificationBoundariesAreRecorded() throws {
    let contract = try loadContract()
    let verification = contract.runtimeVerification
    XCTAssertTrue(verification.axTreeOperatedInAcceptance)
    XCTAssertTrue(verification.requiresTrustedAccessibilityProcess)
    XCTAssertFalse(verification.voiceOverAnnouncementVerified,
                   "Do not claim VoiceOver announcement is verified without a recorded run")
    XCTAssertFalse(verification.unitTestReadsAXTree,
                   "Unit tests validate the contract, not the live AX tree")
    XCTAssertFalse(verification.note.isEmpty)
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: repoRoot.appendingPathComponent(verification.acceptanceEvidence).path))
  }

  /// Look up identifiers across the main panels and assert their declared
  /// state: role, permitted actions, read/write access, scene and idempotency.
  func testLookupResolvesRepresentativeIdentifiers() throws {
    let contract = try loadContract()
    let cases: [(key: String, role: String, actions: [String], access: String, scene: String, idempotent: Bool)] = [
      ("main-go-home", "button", ["press"], "write", "main-window", true),
      ("main-layout-toggle", "button", ["press"], "write", "main-window", false),
      ("native-assistant-input", "textField", ["setValue", "readValue"], "write", "panel:assistant", true),
      ("native-assistant-submit", "button", ["press"], "write", "panel:assistant", false),
      ("assistant-runtime-picker", "popUpButton", ["select", "readValue"], "write", "settings:assistant", true),
      ("assistant-dsh-test", "button", ["press"], "write", "settings:assistant", false),
      ("native-space-controls", "group", ["readValue"], "read", "panel:space", true),
      ("native-space-scan", "button", ["press"], "write", "panel:space", false),
      ("native-browser-address", "textField", ["setValue", "readValue"], "write", "panel:browser", true),
      ("native-browser-go", "button", ["press"], "write", "panel:browser", false),
      ("project-add-folder", "button", ["press"], "write", "panel:project-regions", false),
      ("project-save", "button", ["press"], "write", "panel:project-regions", false),
      ("codex-storage-scan", "button", ["press"], "write", "panel:cleanup", false),
      ("codex-storage-confirm", "button", ["press"], "write", "panel:cleanup", false),
      ("disk-usage-choose", "button", ["press"], "write", "panel:storage-analysis", false),
      ("immersive-voice", "button", ["press"], "write", "immersive", true),
      ("immersive-system-menu", "menuButton", ["press"], "write", "immersive", false),
      ("native-notifications-clear", "button", ["press"], "write", "panel:notifications", false),
      ("native-device-connect", "button", ["press"], "write", "panel:device", false),
    ]
    for expectation in cases {
      let element = try self.element(contract, for: expectation.key)
      XCTAssertEqual(element.key, expectation.key, "lookup resolved the wrong entry")
      XCTAssertEqual(element.role, expectation.role, expectation.key)
      XCTAssertEqual(element.actions, expectation.actions, expectation.key)
      XCTAssertEqual(element.access, expectation.access, expectation.key)
      XCTAssertEqual(element.scene, expectation.scene, expectation.key)
      XCTAssertEqual(element.idempotent, expectation.idempotent, expectation.key)
      XCTAssertTrue(element.reviewed, "\(expectation.key) should be curated before it is asserted")
    }
  }

  func testPatternLookupResolvesDynamicIdentifiers() throws {
    let contract = try loadContract()
    let cases = [
      ("project-select-9F3C4A2E-1111-2222-3333-444455556666", "project-select-{id}"),
      ("project-open-result-vscode", "project-open-result-{id}"),
      ("codex-storage-candidate-0A1B2C3D", "codex-storage-candidate-{id}"),
      ("cleanup-simulator-item-device-1", "cleanup-simulator-item-{id}"),
      ("immersive-dock-weather", "immersive-dock-{id}"),
      ("immersive-github", "immersive-{id}"),
    ]
    for (concrete, expected) in cases {
      XCTAssertEqual(try element(contract, for: concrete).key, expected, concrete)
    }
  }

  func testDeclaredStateMatchesCuratedEntries() throws {
    let contract = try loadContract()
    let input = try element(contract, for: "native-assistant-input")
    XCTAssertEqual(input.label, "输入指令")
    XCTAssertEqual(input.disabledWhen, "store.isBusy")
    XCTAssertEqual(input.preconditions, ["助手不忙"])
    XCTAssertTrue(input.idempotent)

    let submit = try element(contract, for: "native-assistant-submit")
    XCTAssertEqual(submit.preconditions, ["助手不忙", "草稿非空"])
    XCTAssertFalse(submit.idempotent)
    XCTAssertFalse(submit.disabledWhen?.isEmpty ?? true)

    let confirm = try element(contract, for: "codex-storage-confirm")
    XCTAssertTrue(confirm.preconditions.contains("用户在原生 UI 中确认"))
    XCTAssertTrue(confirm.notes.contains("模型不能自行生成批准"))
    XCTAssertTrue(confirm.reviewed)

    let picker = try element(contract, for: "assistant-runtime-picker")
    XCTAssertEqual(picker.disabledWhen, "magpieConfiguration.isManaged")
    XCTAssertTrue(picker.idempotent)
  }

  func testDerivedEntriesAreMarkedUnreviewed() throws {
    let contract = try loadContract()
    let reviewed = contract.elements.filter(\.reviewed)
    XCTAssertGreaterThan(reviewed.count, 0)
    for element in contract.elements where !element.reviewed {
      XCTAssertFalse(element.notes.isEmpty, "\(element.key): derived entries need a review note")
    }
  }
}
