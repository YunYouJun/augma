import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class AugmaLinkTests: XCTestCase {
  func testLinkAndApplicationLibraryHaveSeparateRoutesAndKeepOldCommandsWorking() {
    for phrase in ["Augma Link", "打开 Augma Link", "扩展中心", "Open Extension Center", "打开应用市场"] {
      XCTAssertEqual(WorkspaceCommand.parse(phrase), .open(.market), phrase)
    }
    for phrase in ["应用列表", "打开应用列表", "Open App Library", "アプリ一覧を開く"] {
      XCTAssertEqual(WorkspaceCommand.parse(phrase), .open(.library), phrase)
    }
    XCTAssertEqual(DemoModule.market.localizationKey, "Augma Link · 扩展中心")
    XCTAssertEqual(DemoModule.library.localizationKey, "应用列表")
    XCTAssertEqual(Array(DemoModule.applications.prefix(9)),
      [.weather, .audio, .space, .camera, .navigation, .browser, .notifications, .settings, .commands])
  }

  func testExtensionSearchFindsCapabilitiesAndDoesNotListDiscoveryPagesAsExtensions() {
    XCTAssertTrue(AugmaExtension.catalog.filter { $0.matches(" focus ") }.contains { $0.module == .focus })
    XCTAssertTrue(AugmaExtension.catalog.filter { $0.matches("MONITOR") }.contains { $0.module == .monitor })
    XCTAssertTrue(AugmaExtension.catalog.filter { $0.matches("no-such-extension") }.isEmpty)
    XCTAssertFalse(AugmaExtension.catalog.contains { [.market, .library].contains($0.module) })
    XCTAssertEqual(Set(AugmaExtension.catalog.map(\.id)).count, AugmaExtension.catalog.count)
  }

  func testAnyNativeExtensionCanBePinnedAndRestoredWithAStableModuleIdentity() throws {
    let suite = "augma.link.tests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    for entry in AugmaExtension.catalog {
      let item = NativeDockItem(module: entry.module)
      dock.restore(item)
      dock.restore(item)
      XCTAssertEqual(item.module, entry.module)
      XCTAssertEqual(dock.items.filter { $0.module == entry.module }.count, 1)
    }
    let restored = NativeDockStore(defaults: defaults)
    for entry in AugmaExtension.catalog { XCTAssertTrue(restored.items.contains { $0.module == entry.module }) }
    let notes = NativeDockItem(module: .notes)
    restored.move(notes, by: -1)
    XCTAssertEqual(NativeDockStore(defaults: defaults).items, restored.items)
    restored.remove(notes)
    XCTAssertFalse(NativeDockStore(defaults: defaults).items.contains { $0.module == .notes })
  }
}
