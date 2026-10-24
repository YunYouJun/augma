import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class CraftHubBindingTests: XCTestCase {
  func testConfigurationAcceptsOnlyExplicitLoopbackReadConnection() throws {
    let connection = try CraftHubConnection.parse(config())
    XCTAssertEqual(connection.origin.absoluteString, "http://127.0.0.1:4318")
    XCTAssertEqual(connection.sourceID, try CraftHubConnection.parse(config(port: 4320)).sourceID)
    XCTAssertNotEqual(connection.sourceID, try CraftHubConnection.parse(config(path: "/tmp/other/credential.json")).sourceID)
    for origin in ["https://example.com", "http://localhost:4318", "http://127.0.0.1:4318/api", "http://user:pass@127.0.0.1:4318", "http://127.0.0.1:4318/?token=secret"] {
      XCTAssertThrowsError(try CraftHubConnection(origin: URL(string: origin)!, credentialPath: "/tmp/credential.json").validated())
    }
    XCTAssertThrowsError(try CraftHubConnection.parse(config(path: "relative/credential.json")))
    XCTAssertThrowsError(try CraftHubConnection.parse(config(path: "/tmp/../credential.json")))
    XCTAssertThrowsError(try CraftHubConnection.parse("{\"command\":\"sh\",\"args\":[\"-c\",\"echo run\"]}"))
  }

  func testClientUsesOnlyReadEndpointWithoutBrowserOrHostCredentials() async throws {
    let recorder = HubRequestRecorder()
    let data = Data("[{\"id\":\"shared\",\"name\":\"Shared\",\"path\":\"/tmp/shared\",\"trust\":\"untrusted\"}]".utf8)
    let client = CraftHubClient(transport: { request in
      await recorder.record(request)
      return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }, credential: { _ in Data("{\"token\":\"\(String(repeating: "a", count: 64))\"}".utf8) })
    let projects = try await client.projects(CraftHubConnection.parse(config()))
    XCTAssertEqual(projects.map(\.id), ["shared"])
    let recorded = await recorder.request
    let request = try XCTUnwrap(recorded)
    XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:4318/api/agent-access")
    XCTAssertNil(request.value(forHTTPHeaderField: "Origin"))
    XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
    XCTAssertEqual(body["name"] as? String, "craft_hub_projects")
    XCTAssertFalse(String(data: request.httpBody!, encoding: .utf8)!.contains("token"))
  }

  func testClientRejectsRedirectedOrMismatchedContextAndHidesServerErrors() async throws {
    let connection = try CraftHubConnection.parse(config())
    for status in [302, 401, 403, 500] {
      let client = CraftHubClient(transport: { request in
        (Data("private-server-detail".utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
      }, credential: { _ in Data("{\"token\":\"\(String(repeating: "a", count: 64))\"}".utf8) })
      do { _ = try await client.projects(connection); XCTFail("Expected failure") }
      catch { XCTAssertFalse(error.localizedDescription.contains("private-server-detail")) }
    }
    XCTAssertThrowsError(try makeHubContext(id: "other").validated(projectID: "shared"))
    let invalid = CraftHubProject(id: "../private", name: "Invalid", path: "/tmp", trust: "trusted")
    XCTAssertThrowsError(try invalid.validated())
  }

  func testBoundRegionReadsLatestNameAndFolderWithoutOverwritingIndependentConfiguration() async throws {
    let f = HubBindingFixture(); defer { f.close() }
    let connected = await f.connect(); XCTAssertTrue(connected)
    let id = try XCTUnwrap(f.store.add(folderURL: URL(fileURLWithPath: "/tmp/independent")))
    var draft = f.store.draft(for: f.store.regions[0]); draft.websites = "https://example.com/docs"
    f.store.setDraft(id, draft); XCTAssertTrue(f.store.saveDraft(id))
    let original = f.store.regions[0]
    let binding = try f.hub.binding(for: "shared")
    try await f.hub.read(binding); f.store.bind(id, to: binding)
    XCTAssertEqual(f.store.displayName(f.store.regions[0]), "Shared")
    XCTAssertEqual(f.store.regions[0].folder, original.folder)
    f.remote.current = makeHubContext(name: "Renamed", path: "/tmp/moved")
    await f.store.refreshBinding(id)
    XCTAssertEqual(f.store.presentedRegions[0].name, "Renamed")
    f.store.open(id); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.local.openedFolders, ["/tmp/moved"])
    XCTAssertEqual(f.local.openedWebsites, ["https://example.com/docs"])
    f.store.unlink(id)
    XCTAssertEqual(f.store.regions[0], original)
    f.hub.disconnect()
    f.store.open(id); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.local.openedFolders.last, "/tmp/independent")
  }

  func testRevocationBlocksBoundOpenButStandaloneRegionsRemainUsable() async throws {
    let f = HubBindingFixture(); defer { f.close() }
    let connected = await f.connect(); XCTAssertTrue(connected)
    let binding = try f.hub.binding(for: "shared"); try await f.hub.read(binding)
    let bound = try XCTUnwrap(f.store.add(binding: binding))
    let local = try XCTUnwrap(f.store.add(folderURL: URL(fileURLWithPath: "/tmp/local")))
    f.remote.failure = .unauthorized
    f.store.open(bound); await waitFor { f.store.openingID == nil }
    XCTAssertTrue(f.local.openedFolders.isEmpty)
    XCTAssertFalse(f.hub.connected)
    XCTAssertTrue(f.hub.contexts.isEmpty)
    XCTAssertTrue(f.store.reports[bound]?.hasFailures == true)
    f.store.open(local); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.local.openedFolders, ["/tmp/local"])
  }

  func testDifferentSourceCannotResolveAnExistingBinding() async throws {
    let f = HubBindingFixture(); defer { f.close() }
    let connected = await f.connect(); XCTAssertTrue(connected)
    let binding = try f.hub.binding(for: "shared"); try await f.hub.read(binding)
    let id = try XCTUnwrap(f.store.add(binding: binding))
    let otherSourceConnected = await f.hub.connect(json: config(path: "/tmp/another/credential.json")); XCTAssertTrue(otherSourceConnected)
    XCTAssertNil(f.hub.context(for: binding))
    f.store.open(id); await waitFor { f.store.openingID == nil }
    XCTAssertTrue(f.local.openedFolders.isEmpty)
    XCTAssertTrue(f.store.reports[id]?.hasFailures == true)
  }

  func testDisconnectRejectsLateReadAndKeepsReferenceForReconnection() async throws {
    let f = HubBindingFixture(); defer { f.close() }
    let connected = await f.connect(); XCTAssertTrue(connected)
    let binding = try f.hub.binding(for: "shared"); try await f.hub.read(binding)
    let id = try XCTUnwrap(f.store.add(binding: binding))
    f.remote.pauseNext = true
    let read = Task { try await f.hub.read(binding) }
    await waitFor { f.remote.pending != nil }
    f.hub.disconnect(); f.remote.finishPending()
    do { _ = try await read.value; XCTFail("Late read must be rejected") } catch {}
    XCTAssertNil(f.hub.context(for: binding))
    XCTAssertEqual(f.store.regions[0].craftHub, binding)
    let reconnected = await f.connect(); XCTAssertTrue(reconnected)
    await f.store.refreshBinding(id)
    XCTAssertNotNil(f.hub.context(for: binding))
  }

  func testOlderReadCannotOverwriteNewerProjectDetails() async throws {
    let f = HubBindingFixture(); defer { f.close() }
    let connected = await f.connect(); XCTAssertTrue(connected)
    let binding = try f.hub.binding(for: "shared")
    f.remote.pauseNext = true
    let older = Task { try await f.hub.read(binding) }
    await waitFor { f.remote.pending != nil }
    f.remote.current = makeHubContext(name: "Latest", path: "/tmp/latest")
    try await f.hub.read(binding)
    f.remote.finishPending()
    do { _ = try await older.value; XCTFail("Superseded read must fail") } catch {}
    XCTAssertEqual(f.hub.context(for: binding)?.project.name, "Latest")
    XCTAssertNil(f.hub.error)
  }

  func testBindingPersistenceAndVersionOneMigrationPreserveLocalData() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-binding-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = ProjectWorkspaceFile(url: root.appending(path: "regions.json"))
    let f = HubBindingFixture(); defer { f.close() }
    _ = f.store.add(folderURL: URL(fileURLWithPath: "/tmp/local"))
    let original = f.store.regions
    var old = ProjectWorkspaceDocument(regions: original); old.version = 1
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try JSONEncoder().encode(old).write(to: file.url)
    let migrated = try file.load()
    XCTAssertEqual(migrated.version, 2); XCTAssertEqual(migrated.regions, original)
    let connected = await f.connect(); XCTAssertTrue(connected)
    let binding = try f.hub.binding(for: "shared"); try await f.hub.read(binding)
    f.store.bind(original[0].id, to: binding)
    try file.save(ProjectWorkspaceDocument(regions: f.store.regions))
    XCTAssertEqual(try file.load().regions, f.store.regions)
    let connectionFile = CraftHubConnectionFile(url: root.appending(path: "connection.json"))
    try connectionFile.save(f.hub.connection)
    XCTAssertEqual(try connectionFile.load(), f.hub.connection)
    let text = try String(contentsOf: connectionFile.url, encoding: .utf8)
    XCTAssertFalse(text.contains("token"))
    try connectionFile.save(nil); XCTAssertNil(try connectionFile.load())
  }

  func testNavigationContainsOnlyProjectReferenceAndNeverAnExecutionAction() throws {
    let value = makeHubContext(reference: .init(repository: "https://example.com/team/project", subdir: "apps/web"))
    let url = try XCTUnwrap(value.navigationURL(scheme: "craft-hub-native"))
    XCTAssertEqual(url.host, "project")
    XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name), ["v", "repo", "subdir"])
    XCTAssertNil(value.navigationURL(scheme: "file"))
    XCTAssertEqual(makeHubContext().navigationURL(scheme: "craft-hub")?.host, "open")
  }

  func testRealCraftHubHostContractWhenFixtureIsProvided() async throws {
    guard let path = ProcessInfo.processInfo.environment["AUGMA_CRAFT_HUB_FIXTURE_CONFIG"] else {
      throw XCTSkip("Run script/verify-craft-hub.mjs against a local Craft Hub checkout for the real host contract.")
    }
    let config = try String(contentsOfFile: path, encoding: .utf8)
    let hub = CraftHubConnectionStore(); defer { hub.shutdown() }
    let connected = await hub.connect(json: config); XCTAssertTrue(connected)
    XCTAssertEqual(hub.projects.count, 1)
    let project = try XCTUnwrap(hub.projects.first)
    XCTAssertEqual(project.trust, "untrusted")
    let summary = try await hub.read(hub.binding(for: project.id))
    XCTAssertEqual(summary.project.name, "shared-project")
    XCTAssertEqual(summary.capabilities.map(\.name), ["verify"])
    XCTAssertNotNil(summary.reference)
  }

  private func waitFor(_ predicate: () -> Bool) async {
    for _ in 0..<200 where !predicate() { await Task.yield() }
    XCTAssertTrue(predicate())
  }
}

private func config(port: Int = 4318, path: String = "/tmp/craft-hub/credential.json") -> String {
  let data = try! JSONSerialization.data(withJSONObject: ["mcpServers": ["craft-hub": [
    "command": "node", "args": ["/installed/cli.mjs", "mcp", "--url", "http://127.0.0.1:\(port)", "--credential-file", path],
  ]]])
  return String(decoding: data, as: UTF8.self)
}

private func makeHubContext(id: String = "shared", name: String = "Shared", path: String = "/tmp/shared",
                     reference: CraftHubProjectContext.Reference? = nil) -> CraftHubProjectContext {
  CraftHubProjectContext(project: .init(id: id, name: name, path: path, trust: "untrusted"),
    capabilities: [.init(id: "test", name: "test", kind: "command", description: nil)], reference: reference)
}

private actor HubRequestRecorder {
  var request: URLRequest?
  func record(_ request: URLRequest) { self.request = request }
}

@MainActor
private final class HubBindingFixture {
  let remote = FakeHubReader()
  let local = BindingProjectClient()
  let hub: CraftHubConnectionStore
  let store: ProjectWorkspaceStore
  init() {
    hub = CraftHubConnectionStore(client: remote)
    store = ProjectWorkspaceStore(client: local, craftHub: hub)
  }
  func connect() async -> Bool { await hub.connect(json: config()) }
  func close() { remote.finishPending(); store.shutdown() }
}

@MainActor
private final class FakeHubReader: CraftHubReading {
  var current = makeHubContext()
  var failure: CraftHubError?
  var pauseNext = false
  var pending: CheckedContinuation<Void, Never>?
  func projects(_ connection: CraftHubConnection) async throws -> [CraftHubProject] {
    if let failure { throw failure }; return [current.project]
  }
  func context(_ connection: CraftHubConnection, projectID: String) async throws -> CraftHubProjectContext {
    let result = current
    if pauseNext { pauseNext = false; await withCheckedContinuation { pending = $0 } }
    if let failure { throw failure }; return result
  }
  func finishPending() { let old = pending; pending = nil; old?.resume() }
}


@MainActor
private final class BindingProjectClient: ProjectWorkspaceClient {
  var openedFolders: [String] = []
  var openedWebsites: [String] = []
  func captureFolder(_ url: URL) throws -> ProjectFolder { .init(bookmark: Data(url.path.utf8), displayPath: url.path, securityScoped: false) }
  func defaultApplication(_ id: String) -> ProjectApplication? { nil }
  func inspectApplication(_ url: URL, expectedID: String) throws -> ProjectApplication { throw ProjectWorkspaceError.applicationUnavailable }
  func openEditor(folder: ProjectFolder, application: ProjectApplication?) async throws { openedFolders.append(folder.displayPath) }
  func openWebsite(_ url: URL, application: ProjectApplication?) async throws { openedWebsites.append(url.absoluteString) }
  func revealFolder(_ folder: ProjectFolder) throws {}
}
