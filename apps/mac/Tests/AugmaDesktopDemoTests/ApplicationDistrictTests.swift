import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ApplicationDistrictTests: XCTestCase {
  func testApplicationsUseBundleIdentifiersAndDuplicateAddsPreserveLayout() {
    let fixture = DistrictFixture()
    defer { fixture.close() }
    fixture.add("one", name: "Editor")
    fixture.add("two", name: "Editor")
    fixture.store.rename("one", to: "Development")
    fixture.store.move("one", to: 9)
    fixture.store.setFixed("one", true)
    fixture.client.apps["one"] = InstalledApplication(id: "one", name: "Editor 2", path: "/Applications/Moved.app")
    XCTAssertEqual(fixture.store.add(url: URL(fileURLWithPath: "/Applications/Moved.app")), "one")
    XCTAssertEqual(fixture.store.buildings.count, 2)
    let item = fixture.store.buildings.first { $0.id == "one" }!
    XCTAssertEqual(item.title, "Development")
    XCTAssertEqual(item.slot, 9)
    XCTAssertTrue(item.fixed)
    XCTAssertEqual(item.applicationPath, "/Applications/Moved.app")
  }

  func testMoveSwapsAndFixedPositionsSurviveRearranging() {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one"); f.add("two"); f.add("three")
    f.store.move("one", to: 1)
    XCTAssertEqual(f.store.buildings.map(\.slot), [1, 0, 2])
    f.store.setFixed("one", true)
    f.store.move("two", to: 1)
    XCTAssertNotNil(f.store.error)
    XCTAssertEqual(f.store.buildings.map(\.slot), [1, 0, 2])
    f.store.move("three", to: 11)
    f.store.restoreLayout()
    XCTAssertEqual(f.store.buildings.map(\.slot), [1, 0, 2])
    XCTAssertEqual(Set(f.store.buildings.map(\.position)).count, 3)
  }

  func testCapacityAndInvalidNamesCannotCorruptTheLayout() {
    let f = DistrictFixture(); defer { f.close() }
    for index in 0..<13 { f.add("app\(index)") }
    XCTAssertEqual(f.store.buildings.count, 12)
    XCTAssertNotNil(f.store.error)
    f.store.rename("app0", to: String(repeating: "a", count: 41))
    XCTAssertEqual(f.store.buildings[0].nickname, "")
    f.store.rename("app0", to: "first\nsecond")
    XCTAssertEqual(f.store.buildings[0].nickname, "")
    XCTAssertNoThrow(try ApplicationDistrictDocument(buildings: f.store.buildings).validated())
  }

  func testRemoveAndUndoPreserveNamesAndChooseAnUnoccupiedSlot() {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one"); f.add("two")
    f.store.rename("one", to: "My editor")
    f.store.remove("one")
    f.add("three")
    f.store.undoRemoval()
    XCTAssertEqual(f.store.buildings.count, 3)
    XCTAssertEqual(f.store.buildings.first { $0.id == "one" }?.title, "My editor")
    XCTAssertEqual(Set(f.store.buildings.map(\.slot)).count, 3)
    XCTAssertFalse(f.store.canUndoRemoval)
  }

  func testWorkspaceEventsUpdateRunningFrontmostAndMissingWithoutPollingOrSaving() {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one")
    let writes = f.persistence.writes
    XCTAssertEqual(f.store.states["one"], .stopped)
    f.client.states["one"] = .running; f.client.onChange?()
    XCTAssertEqual(f.store.states["one"], .running)
    f.client.states["one"] = .frontmost; f.client.onChange?()
    XCTAssertEqual(f.store.states["one"], .frontmost)
    f.client.apps["one"] = nil; f.client.onChange?()
    XCTAssertEqual(f.store.states["one"], .missing)
    XCTAssertEqual(f.store.buildings.count, 1)
    XCTAssertEqual(f.persistence.writes, writes)
  }

  func testOpenResolvesMovedApplicationsAndPreventsDuplicateRequests() async {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one")
    f.client.apps["one"] = InstalledApplication(id: "one", name: "one", path: "/Applications/New Location.app")
    f.client.delays = true
    var opened: [String] = []
    f.store.onOpen = { opened.append($0) }
    f.store.open("one"); f.store.open("one")
    await f.client.waitForRequest()
    XCTAssertEqual(f.client.opens.map(\.path), ["/Applications/New Location.app"])
    f.client.complete()
    for _ in 0..<10 { await Task.yield() }
    XCTAssertEqual(opened, ["one"])
    XCTAssertFalse(f.store.opening.contains("one"))
  }

  func testMissingAndFailedLaunchKeepTheBuildingAndReportTheFailure() async {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one")
    f.client.apps["one"] = nil
    f.store.open("one")
    XCTAssertTrue(f.client.opens.isEmpty)
    XCTAssertNotNil(f.store.error)
    f.client.apps["one"] = InstalledApplication(id: "one", name: "one", path: "/Applications/one.app")
    f.client.failOpen = true
    f.store.open("one")
    for _ in 0..<10 { await Task.yield() }
    XCTAssertEqual(f.store.buildings.count, 1)
    XCTAssertNotNil(f.store.error)
    XCTAssertTrue(f.store.opening.isEmpty)
  }

  func testRemovingDuringLaunchRejectsItsLateCompletion() async {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one"); f.client.delays = true
    var opened = false
    f.store.onOpen = { _ in opened = true }
    f.store.open("one")
    await f.client.waitForRequest()
    f.store.remove("one")
    f.client.complete()
    for _ in 0..<10 { await Task.yield() }
    XCTAssertFalse(opened)
    XCTAssertTrue(f.store.buildings.isEmpty)
    XCTAssertTrue(f.store.opening.isEmpty)
  }

  func testSaveFailureKeepsChangesVisibleAndRetrySavesLatestLayout() {
    let f = DistrictFixture(); defer { f.close() }
    f.add("one")
    f.persistence.failSave = true
    f.store.move("one", to: 7)
    XCTAssertEqual(f.store.buildings[0].slot, 7)
    XCTAssertNotNil(f.store.saveError)
    XCTAssertEqual(f.persistence.document.buildings[0].slot, 0)
    f.persistence.failSave = false
    f.store.retrySave()
    XCTAssertNil(f.store.saveError)
    XCTAssertEqual(f.persistence.document.buildings[0].slot, 7)
  }

  func testMainWindowsAndImmersivePresentationShareOnePersistentCatalog() {
    let f = DistrictFixture(); defer { f.close() }
    let first = NativeDemoModel(applications: f.store)
    let second = NativeDemoModel(applications: f.store)
    defer { first.closeScene(); second.closeScene() }
    f.add("one")
    first.space.selectScene(.workspace)
    first.space.selectedApplicationID = "one"
    first.space.setView(yaw: 0.3, pitch: 0.2, scale: 1.1)
    first.setImmersive(true); first.setImmersive(false)
    XCTAssertTrue(first.space.applications === second.space.applications)
    XCTAssertEqual(first.space.selectedApplicationID, "one")
    XCTAssertEqual(first.space.viewYaw, 0.3, accuracy: 0.001)
    first.closeScene()
    f.store.rename("one", to: "Work")
    XCTAssertEqual(second.space.applications.buildings[0].title, "Work")
    let restored = ApplicationDistrictStore(client: f.client, persistence: f.persistence)
    XCTAssertEqual(restored.buildings, f.store.buildings)
  }

  func testRealFileRoundTripAndMalformedLayoutPreservation() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "augma-district-test-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = ApplicationDistrictFile(url: folder.appending(path: "layout.json"))
    let document = ApplicationDistrictDocument(buildings: [ApplicationBuilding(id: "test.app", applicationName: "Test", applicationPath: "/Applications/Test.app", nickname: "Work", slot: 6, fixed: true)])
    try file.save(document)
    XCTAssertEqual(try file.load(), document)
    let broken = Data("{broken".utf8)
    try broken.write(to: file.url)
    let store = ApplicationDistrictStore(client: FakeApplications(), persistence: file)
    defer { store.shutdown() }
    XCTAssertFalse(store.writable)
    store.retrySave()
    XCTAssertEqual(try Data(contentsOf: file.url), broken)
    store.rebuildUnreadableLayout()
    XCTAssertTrue(store.writable)
    XCTAssertTrue(try file.load().buildings.isEmpty)
    let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
      .filter { $0.lastPathComponent.hasPrefix("application-district-preserved-") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: backups[0]), broken)
  }

  func testLayoutRejectsUnknownVersionsDuplicatesAndInvalidSlots() {
    let one = ApplicationBuilding(id: "one", applicationName: "One", applicationPath: "/Applications/One.app", slot: 0)
    XCTAssertThrowsError(try ApplicationDistrictDocument(version: 2, buildings: [one]).validated())
    XCTAssertThrowsError(try ApplicationDistrictDocument(buildings: [one, one]).validated())
    var invalid = one; invalid.slot = 12
    XCTAssertThrowsError(try ApplicationDistrictDocument(buildings: [invalid]).validated())
    invalid = one; invalid.applicationPath = "/tmp/file.txt"
    XCTAssertThrowsError(try ApplicationDistrictDocument(buildings: [invalid]).validated())
  }

  func testRealAppInspectionRejectsAReplacementWithAnotherBundleID() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-app-inspection-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let app = root.appending(path: "Example.app")
    let executable = app.appending(path: "Contents/MacOS/Example")
    try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    let identifier = "test.augma." + UUID().uuidString
    func writeInfo(_ id: String) throws {
      let values = ["CFBundleIdentifier": id, "CFBundleExecutable": "Example", "CFBundleName": "Example", "CFBundlePackageType": "APPL"]
      try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0).write(to: app.appending(path: "Contents/Info.plist"))
    }
    try writeInfo(identifier)
    let client = SystemInstalledApplicationClient()
    let info = try client.inspect(app)
    XCTAssertEqual(info.id, identifier)
    let building = ApplicationBuilding(id: info.id, applicationName: info.name, applicationPath: info.path, slot: 0)
    try writeInfo("replacement." + identifier)
    XCTAssertNil(client.resolve(building))
    XCTAssertThrowsError(try client.inspect(executable))
  }
}

@MainActor
private final class DistrictFixture {
  let client = FakeApplications()
  let persistence = FakeDistrictPersistence()
  lazy var store = ApplicationDistrictStore(client: client, persistence: persistence, observeLifecycle: true)
  func add(_ id: String, name: String? = nil) {
    let app = InstalledApplication(id: id, name: name ?? id, path: "/Applications/\(id).app")
    client.apps[id] = app
    _ = store.add(url: URL(fileURLWithPath: app.path))
  }
  func close() { client.complete(); store.shutdown() }
}

@MainActor
private final class FakeDistrictPersistence: ApplicationDistrictPersisting {
  var document = ApplicationDistrictDocument()
  var writes = 0
  var failSave = false
  func load() throws -> ApplicationDistrictDocument { document }
  func save(_ value: ApplicationDistrictDocument) throws {
    if failSave { throw CocoaError(.fileWriteNoPermission) }
    document = value; writes += 1
  }
  func preserveUnreadableFile() throws {}
}

@MainActor
private final class FakeApplications: InstalledApplicationClient {
  var onChange: (() -> Void)?
  var apps: [String: InstalledApplication] = [:]
  var states: [String: ApplicationRunState] = [:]
  var opens: [InstalledApplication] = []
  var delays = false
  var failOpen = false
  private var continuation: CheckedContinuation<Void, Error>?
  func inspect(_ url: URL) throws -> InstalledApplication {
    guard let app = apps.values.first(where: { $0.path == url.path }) else { throw ApplicationDistrictError.notApplication }
    return app
  }
  func resolve(_ building: ApplicationBuilding) -> InstalledApplication? { apps[building.id] }
  func suggestions() -> [InstalledApplication] { Array(apps.values) }
  func icon(for application: InstalledApplication) -> NSImage { NSImage(size: NSSize(width: 32, height: 32)) }
  func runningStates() -> [String: ApplicationRunState] { states }
  func startObserving() {}
  func stopObserving() { onChange = nil }
  func open(_ application: InstalledApplication) async throws {
    opens.append(application)
    if failOpen { throw ApplicationDistrictError.activationFailed }
    if delays { try await withCheckedThrowingContinuation { continuation = $0 } }
    states[application.id] = .frontmost
  }
  func waitForRequest() async { for _ in 0..<30 where opens.isEmpty { await Task.yield() } }
  func complete() { continuation?.resume(); continuation = nil }
}
