import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class AssistantMagpieConfigurationTests: XCTestCase {
  private func fixture() throws -> (AssistantMagpieConfiguration, UserDefaults, URL) {
    let name = "AugmaMagpieTests.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    addTeardownBlock {
      UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: directory)
    }
    defaults.set("group/augma", forKey: AssistantRuntimeSettings.modelKey)
    defaults.set("medium", forKey: AssistantRuntimeSettings.reasoningKey)
    defaults.set(true, forKey: AssistantRuntimeSettings.enabledKey)
    defaults.set(AssistantRuntimeSettings.fingerprint(defaults), forKey: AssistantRuntimeSettings.testedKey)
    let file = directory.appendingPathComponent("magpie.json")
    return (AssistantMagpieConfiguration(defaults: defaults, file: file), defaults, file)
  }

  func testMigrationKeepsConsentAndExternalEditRequiresANewTest() throws {
    let (config, defaults, file) = try fixture()
    config.refresh()
    XCTAssertTrue(defaults.bool(forKey: AssistantRuntimeSettings.enabledKey))
    XCTAssertNil(defaults.object(forKey: AssistantRuntimeSettings.backendKey))
    let original = try Data(contentsOf: file)
    try Data(#"{"version":1,"runtime":"dsh","model":"codex/gpt-6.1-terra","effort":"high","managed":true}"#.utf8)
      .write(to: file, options: .atomic)
    config.refresh()
    XCTAssertTrue(config.isManaged)
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.modelKey), "codex/gpt-6.1-terra")
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.reasoningKey), "high")
    XCTAssertFalse(defaults.bool(forKey: AssistantRuntimeSettings.enabledKey))
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.testedKey), "")
    XCTAssertTrue(config.hasModel("codex/gpt-6.1-terra"))
    XCTAssertTrue(config.hasEffort("high"))
    try original.write(to: file, options: .atomic)
    config.refresh()
    XCTAssertFalse(config.isManaged)
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.modelKey), "group/augma")
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.reasoningKey), "medium")
  }

  func testLocalWritePreservesUnknownKeysAndDoesNotClobberExternalEdit() throws {
    let (config, defaults, file) = try fixture()
    config.refresh()
    try Data(#"{"version":1,"runtime":"dsh","model":"group/augma","effort":"medium","future":{"keep":true}}"#.utf8)
      .write(to: file, options: .atomic)
    config.refresh()
    defaults.set("low", forKey: AssistantRuntimeSettings.reasoningKey)
    config.saveLocal()
    let root = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    XCTAssertEqual(root["effort"] as? String, "low")
    XCTAssertEqual((root["future"] as? [String: Bool])?["keep"], true)
    let external = Data(#"{"version":1,"runtime":"dsh","model":"group/augma","effort":"high","managed":true}"#.utf8)
    try external.write(to: file, options: .atomic)
    defaults.set("medium", forKey: AssistantRuntimeSettings.reasoningKey)
    config.saveLocal()
    XCTAssertEqual(try Data(contentsOf: file), external)
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.reasoningKey), "high")
  }

  func testInvalidConfigurationFailsClosedAndIsNeverOverwritten() throws {
    let (config, defaults, file) = try fixture()
    config.refresh()
    for text in ["{", #"{"version":2,"runtime":"dsh","model":"group/augma","effort":"medium"}"#,
                 #"{"version":1,"runtime":"dsh","model":"group/augma","effort":"ultra"}"#,
                 #"{"version":1,"runtime":"deepseek","model":"group/augma","effort":"medium","managed":true}"#] {
      let data = Data(text.utf8)
      try data.write(to: file, options: .atomic)
      defaults.set(true, forKey: AssistantRuntimeSettings.enabledKey)
      config.refresh()
      config.saveLocal()
      XCTAssertFalse(config.failure.isEmpty)
      XCTAssertFalse(defaults.bool(forKey: AssistantRuntimeSettings.enabledKey))
      XCTAssertEqual(try Data(contentsOf: file), data)
      XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.reasoningKey), "medium")
    }
  }

  func testPluginOptionsChangeWithoutAgentFileChangeRequiresRetestAndDisconnectRestoresEffort() throws {
    let (_, defaults, file) = try fixture()
    let options = file.deletingLastPathComponent().appendingPathComponent("plugins.json")
    let config = AssistantMagpieConfiguration(defaults: defaults, file: file, pluginOptionsFile: options)
    config.refresh()
    let original = try Data(contentsOf: file)
    let managed = Data(#"{"version":1,"runtime":"dsh","model":"group/augma","effort":"medium","managed":true,"plugin":"magpie-plugin-augma"}"#.utf8)
    try managed.write(to: file)
    try Data(#"{"plugins":[{"options":{"effort":{"unrelated":true}}},{"options":{"integration":"augma-v1","effort":"medium"}}]}"#.utf8).write(to: options)
    config.refresh()
    XCTAssertTrue(config.failure.isEmpty)
    defaults.set(true, forKey: AssistantRuntimeSettings.enabledKey)
    defaults.set("tested", forKey: AssistantRuntimeSettings.testedKey)
    try Data(#"{"plugins":[{"options":{"integration":"augma-v1","effort":"low"}}]}"#.utf8).write(to: options)
    config.refresh()
    XCTAssertTrue(config.isManaged)
    XCTAssertTrue(config.hasEffort("low"))
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.reasoningKey), "low")
    XCTAssertFalse(defaults.bool(forKey: AssistantRuntimeSettings.enabledKey))
    XCTAssertEqual(defaults.string(forKey: AssistantRuntimeSettings.testedKey), "")
    XCTAssertEqual(try Data(contentsOf: file), managed)
    try original.write(to: file)
    try FileManager.default.removeItem(at: options)
    config.refresh()
    XCTAssertTrue(config.failure.isEmpty)
    XCTAssertFalse(config.isManaged)
    XCTAssertTrue(config.hasEffort("medium"))
  }

  func testMissingDisabledAmbiguousOrInvalidPluginCannotReuseTestedSession() throws {
    let (_, defaults, file) = try fixture()
    let options = file.deletingLastPathComponent().appendingPathComponent("plugins.json")
    let config = AssistantMagpieConfiguration(defaults: defaults, file: file, pluginOptionsFile: options)
    config.refresh()
    try Data(#"{"version":1,"runtime":"dsh","model":"group/augma","effort":"medium","managed":true,"plugin":"magpie-plugin-augma"}"#.utf8).write(to: file)
    for text in [#"{"plugins":[]}"#,
                 #"{"plugins":[{"off":true,"options":{"integration":"augma-v1","effort":"medium"}}]}"#,
                 #"{"plugins":[{"options":{"integration":"augma-v1","effort":"invalid"}}]}"#,
                 #"{"plugins":[{"options":{"integration":"augma-v1","effort":"low"}},{"options":{"integration":"augma-v1","effort":"medium"}}]}"#] {
      try Data(text.utf8).write(to: options)
      defaults.set(true, forKey: AssistantRuntimeSettings.enabledKey)
      config.refresh()
      XCTAssertFalse(config.failure.isEmpty)
      XCTAssertFalse(defaults.bool(forKey: AssistantRuntimeSettings.enabledKey))
    }
    try FileManager.default.removeItem(at: options)
    config.refresh()
    XCTAssertFalse(config.failure.isEmpty)
  }
}
