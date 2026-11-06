import AppKit
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ApplicationLibraryTests: XCTestCase {
  private let app = InstalledApplication(id: "dev.example.editor", name: "编辑器", path: "/Applications/Editor.app")

  func testIndexScansApplicationFoldersDeduplicatesAndSkipsNestedHelpers() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-library-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let user = root.appending(path: "User"), system = root.appending(path: "System")
    try makeApplication(user.appending(path: "Utilities/Editor.app"), id: app.id, name: "Editor")
    try makeApplication(system.appending(path: "Editor.app"), id: app.id, name: "Editor Duplicate")
    try makeApplication(system.appending(path: "Browser.app"), id: "dev.example.browser", name: "Browser")
    try makeApplication(system.appending(path: "Browser.app/Contents/Helpers/Hidden.app"), id: "dev.example.helper", name: "Helper")
    try FileManager.default.createDirectory(at: system.appending(path: "Invalid.app"), withIntermediateDirectories: true)
    let client = SystemApplicationLibraryClient(roots: [user, system])
    let applications = try await client.installedApplications()
    XCTAssertEqual(applications.map(\.name), ["Browser", "Editor"])
    XCTAssertEqual(applications.last?.path, user.appending(path: "Utilities/Editor.app").path)
  }

  func testLocalSearchMatchesLocalizedNameBundleIDAndFilename() async {
    let client = LibraryClient(applications: [app])
    let store = ApplicationLibraryStore(client: client)
    await store.refresh()
    for query in [" 编辑器 ", "DEV.EXAMPLE.EDITOR", "Editor", ""] {
      XCTAssertEqual(store.filteredApplications(query), [app])
    }
    XCTAssertTrue(store.filteredApplications("missing").isEmpty)
    XCTAssertEqual(store.installedApplication(bundleID: app.id), app)
    XCTAssertNil(store.installedApplication(bundleID: "other"))
  }

  func testExplicitSystemAppRootIncludesAppButDoesNotExposeHelpers() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-system-app-\(UUID()).app")
    defer { try? FileManager.default.removeItem(at: root) }
    try makeApplication(root, id: "com.example.finder", name: "Finder")
    try makeApplication(root.appending(path: "Contents/Helpers/Helper.app"), id: "com.example.helper", name: "Helper")
    let applications = try await SystemApplicationLibraryClient(roots: [root]).installedApplications()
    XCTAssertEqual(applications.map(\.id), ["com.example.finder"])
  }

  func testStoreResponseDeduplicatesAndBuildsMacAppStoreHandoff() throws {
    let data = Data(#"{"results":[{"trackId":1,"trackName":"Editor","bundleId":"dev.example.editor","artistName":"Developer","formattedPrice":"¥18.00","artworkUrl100":"https://example.com/icon.png"},{"trackId":1,"trackName":"Duplicate","bundleId":"dev.example.editor"},{"trackId":2,"trackName":"Missing bundle"},{"trackId":3,"trackName":"Browser","bundleId":"dev.example.browser","artworkUrl100":"http://example.com/icon.png"}]}"#.utf8)
    let results = try SystemApplicationLibraryClient.decode(data, country: "cn")
    XCTAssertEqual(results.map(\.id), [1, 3])
    XCTAssertEqual(results.first?.price, "¥18.00")
    XCTAssertEqual(results.first?.storeURL.absoluteString, "macappstore://apps.apple.com/cn/app/id1")
    XCTAssertNotNil(results.first?.iconURL)
    XCTAssertNil(results.last?.iconURL)
    XCTAssertThrowsError(try SystemApplicationLibraryClient.decode(Data("{}".utf8), country: "us"))
  }

  func testLateSearchCannotReplaceNewerResults() async {
    let client = PendingLibraryClient()
    let store = ApplicationLibraryStore(client: client)
    let old = Task { await store.search("old") }
    await client.waitForSearch("old")
    let latest = Task { await store.search("latest") }
    await client.waitForSearch("latest")
    let result = storeApplication(id: 2)
    await client.complete("latest", results: [result])
    await latest.value
    await client.complete("old", results: [storeApplication(id: 1)])
    await old.value
    XCTAssertEqual(store.results, [result])
    XCTAssertTrue(store.hasSearched)
    XCTAssertFalse(store.isSearching)
  }

  func testCancellationAndEditingQueryDiscardLateResults() async {
    let client = PendingLibraryClient()
    let store = ApplicationLibraryStore(client: client)
    let task = Task { await store.search("cancel") }
    await client.waitForSearch("cancel")
    task.cancel()
    await client.complete("cancel", results: [storeApplication()])
    await task.value
    XCTAssertFalse(store.isSearching)
    XCTAssertFalse(store.hasSearched)
    XCTAssertTrue(store.results.isEmpty)
    let edited = Task { await store.search("edited") }
    await client.waitForSearch("edited")
    store.clearSearch()
    await client.complete("edited", results: [storeApplication()])
    await edited.value
    XCTAssertTrue(store.results.isEmpty)
    XCTAssertFalse(store.hasSearched)
  }

  func testSearchErrorIsVisibleAndEmptyQueryMakesNoRequest() async {
    let client = PendingLibraryClient()
    let store = ApplicationLibraryStore(client: client)
    await store.search("   ")
    XCTAssertFalse(store.hasSearched)
    let task = Task { await store.search("error") }
    await client.waitForSearch("error")
    await client.fail("error")
    await task.value
    XCTAssertFalse(store.searchError.isEmpty)
    XCTAssertFalse(store.isSearching)
    XCTAssertTrue(store.results.isEmpty)
  }

  func testStoreHandoffThenRefreshEnablesPinningInstalledApplication() async {
    let client = LibraryClient()
    let workspace = LibraryWorkspace()
    workspace.applications[app.id] = app
    var opened: URL?
    let store = ApplicationLibraryStore(client: client, workspace: workspace, openURL: { opened = $0; return true })
    let entry = storeApplication()
    await store.refresh()
    XCTAssertNil(store.installedApplication(bundleID: app.id))
    store.openStore(entry)
    XCTAssertEqual(opened, entry.storeURL)
    await client.install(app)
    await store.refresh()
    XCTAssertEqual(store.installedApplication(bundleID: app.id), app)
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      for index in 0..<40 {
        dock.restore(.application(.init(id: "test.\(index)", name: "App", path: "/Applications/App.app")))
      }
      store.addToDock(app, dock: dock)
      store.addToDock(app, dock: dock)
      XCTAssertEqual(dock.items.filter { $0.application?.id == app.id }.count, 1)
      XCTAssertTrue(NativeDockStore(defaults: defaults).contains(app))
      XCTAssertTrue(store.actionError.isEmpty)
    }
  }

  func testPinRejectsApplicationReplacedByDifferentBundle() {
    let workspace = LibraryWorkspace()
    workspace.applications["other"] = .init(id: "other", name: "Other", path: app.path)
    let store = ApplicationLibraryStore(workspace: workspace)
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      store.addToDock(app, dock: dock)
      XCTAssertFalse(dock.contains(app))
      XCTAssertFalse(store.actionError.isEmpty)
    }
  }

  func testDockUpdatesAppPathWithoutDuplicatingOrChangingPosition() {
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      dock.restore(.application(app))
      dock.move(.application(app), by: -1)
      let index = dock.items.firstIndex { $0.application?.id == app.id }
      let moved = InstalledApplication(id: app.id, name: app.name, path: "/Applications/Tools/Editor.app")
      dock.restore(.application(moved))
      let restarted = NativeDockStore(defaults: defaults)
      XCTAssertEqual(restarted.items.firstIndex { $0.application?.id == app.id }, index)
      XCTAssertEqual(restarted.items.compactMap(\.application), [moved])
      restarted.beginDrag(.application(moved))
      restarted.previewMove(over: .mirror)
      XCTAssertTrue(restarted.commitDrop())
      XCTAssertEqual(NativeDockStore(defaults: defaults).items.first, .application(moved))
      restarted.remove(.application(app))
      XCTAssertFalse(restarted.contains(moved))
    }
  }

  func testDockOpensMovedAppAndPreservesMissingEntryOnFailure() async {
    let suite = "augma.library.tests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let workspace = LibraryWorkspace()
    let dock = NativeDockStore(defaults: defaults, client: workspace)
    dock.restore(.application(app))
    let moved = InstalledApplication(id: app.id, name: app.name, path: "/Applications/New/Editor.app")
    workspace.applications[app.id] = moved
    var openedID: String?
    dock.onOpen = { openedID = $0 }
    await dock.open(.application(app))
    XCTAssertEqual(workspace.opened, [moved])
    XCTAssertEqual(openedID, app.id)
    workspace.applications = [:]
    openedID = nil
    await dock.open(.application(app))
    XCTAssertEqual(workspace.opened.count, 1)
    XCTAssertNil(openedID)
    XCTAssertFalse(dock.launchError.isEmpty)
    XCTAssertTrue(dock.contains(app))
  }

  func testCleanupRequestSelectsToolsTab() {
    let store = ApplicationMarketStore()
    XCTAssertEqual(store.section, .plugins)
    XCTAssertTrue(store.requestCleanup(DiskCleanupGoal.example))
    XCTAssertEqual(store.section, .tools)
  }

  func testLibraryRendersInstalledAppsAndStoreAtNarrowAndWideSizes() async throws {
    let store = ApplicationLibraryStore(client: LibraryClient(applications: [app], results: [storeApplication()]))
    await store.refresh()
    await store.search("editor")
    let suite = "augma.library.render.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    for section in [ApplicationLibrarySection.installed, .store] {
      for width in [380, 760] {
        for dark in [false, true] {
          let content = ApplicationLibraryView(store: store, dock: dock, section: section)
            .frame(width: CGFloat(width), height: 760)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, dark ? .dark : .light)
          let host = NSHostingView(rootView: content)
          host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
          host.frame = NSRect(x: 0, y: 0, width: width, height: 760)
          host.layoutSubtreeIfNeeded()
          XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
          if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_LIBRARY_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
              .write(to: URL(fileURLWithPath: directory).appending(path: "\(section.rawValue)-\(width)-\(dark ? "dark" : "light").png"))
          }
        }
      }
    }
  }

  func testRealMacAppStoreSearchAndSystemIndexWhenRequested() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_APP_STORE"] == "1" else { throw XCTSkip("Opt-in App Store query") }
    let client = SystemApplicationLibraryClient(roots: [], country: "cn")
    let results = try await client.search("Pages")
    XCTAssertTrue(results.contains { $0.bundleID == "com.apple.Pages" })
    XCTAssertTrue(results.allSatisfy { $0.storeURL.scheme == "macappstore" })
    let installed = try await SystemApplicationLibraryClient().installedApplications()
    XCTAssertTrue(installed.contains { $0.id == "com.apple.Safari" })
    XCTAssertTrue(installed.contains { $0.id == "com.apple.finder" })
  }

  private func storeApplication(id: Int = 1) -> StoreApplication {
    .init(id: id, bundleID: app.id, name: "Editor", developer: "Developer", price: "", iconURL: nil,
      storeURL: URL(string: "macappstore://apps.apple.com/us/app/id\(id)")!)
  }

  private func withDefaults(_ body: (UserDefaults) -> Void) {
    let suite = "augma.library.tests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    body(defaults)
  }

  private func makeApplication(_ url: URL, id: String, name: String) throws {
    let macOS = url.appending(path: "Contents/MacOS")
    try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
    let info = ["CFBundleIdentifier": id, "CFBundleName": name, "CFBundleExecutable": "main"]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
      .write(to: url.appending(path: "Contents/Info.plist"))
    let executable = macOS.appending(path: "main")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
  }
}

private actor LibraryClient: ApplicationLibraryProviding {
  var applications: [InstalledApplication]
  let results: [StoreApplication]
  init(applications: [InstalledApplication] = [], results: [StoreApplication] = []) {
    self.applications = applications; self.results = results
  }
  func installedApplications() async throws -> [InstalledApplication] { applications }
  func search(_ query: String) async throws -> [StoreApplication] { results }
  func install(_ application: InstalledApplication) { applications.append(application) }
}

private actor PendingLibraryClient: ApplicationLibraryProviding {
  var searches: [String: CheckedContinuation<[StoreApplication], Error>] = [:]
  func installedApplications() async throws -> [InstalledApplication] { [] }
  func search(_ query: String) async throws -> [StoreApplication] {
    try await withCheckedThrowingContinuation { searches[query] = $0 }
  }
  func waitForSearch(_ query: String) async { while searches[query] == nil { await Task.yield() } }
  func complete(_ query: String, results: [StoreApplication]) { searches.removeValue(forKey: query)?.resume(returning: results) }
  func fail(_ query: String) { searches.removeValue(forKey: query)?.resume(throwing: URLError(.notConnectedToInternet)) }
}

@MainActor
private final class LibraryWorkspace: InstalledApplicationClient {
  var onChange: (() -> Void)?
  var applications: [String: InstalledApplication] = [:]
  var opened: [InstalledApplication] = []
  func inspect(_ url: URL) throws -> InstalledApplication {
    guard let app = applications.values.first(where: { $0.path == url.path }) else { throw ApplicationDistrictError.notApplication }
    return app
  }
  func resolve(_ building: ApplicationBuilding) -> InstalledApplication? { applications[building.id] }
  func suggestions() -> [InstalledApplication] { [] }
  func icon(for application: InstalledApplication) -> NSImage { NSImage(size: .init(width: 32, height: 32)) }
  func runningStates() -> [String: ApplicationRunState] { [:] }
  func open(_ application: InstalledApplication) async throws { opened.append(application) }
  func startObserving() {}
  func stopObserving() {}
}
