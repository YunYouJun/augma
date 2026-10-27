import AppKit
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

final class ApplicationMarketTests: XCTestCase {
  func testGoalUnderstandsCapacityAndDefaultsToConservativeProtection() throws {
    let goal = try XCTUnwrap(DiskCleanupGoal.parse(DiskCleanupGoal.example))
    XCTAssertEqual(goal.targetBytes, 20_000_000_000)
    XCTAssertTrue(goal.keepModels && goal.keepRecentProjects)
    XCTAssertEqual(DiskCleanupGoal.parse("free 1.5 GiB of disk space")?.targetBytes, 1_610_612_736)
    XCTAssertEqual(DiskCleanupGoal.parse("モデルと最近のプロジェクトを残しつつ、できるだけ 20 GB 空けて。")?.targetBytes, 20_000_000_000)
    XCTAssertEqual(DiskCleanupGoal.parse("Help free up to 20 GB, keeping models and recent projects.")?.targetBytes, 20_000_000_000)
    for text in ["不要清理磁盘", "先别腾出 20 GB", "don't clean disk", "腾出 0 GB", "腾出 999999999 TB", "天气如何",
                 "帮我腾出 20 GB，保留安装包", "free 20 GB, keep my photos", "只清理浏览器缓存腾出 20 GB", "清理微信缓存"] {
      XCTAssertNil(DiskCleanupGoal.parse(text))
    }
  }

  func testReportRejectsForeignPathsAndPreservesIncompleteStatus() throws {
    let scope = URL(filePath: "/fixture")
    let report = try MoleDiskReport.parse(#"{"path":"/fixture","scan_status":"partial","entries":[{"path":"/fixture/Models","size":100}]}"#, scope: scope)
    XCTAssertTrue(report.incomplete)
    XCTAssertEqual(report.entries.first?.name, "Models")
    for json in [
      #"{"path":"/other","entries":[]}"#,
      #"{"path":"/fixture","entries":[{"path":"/fixture/../private","size":2}]}"#,
      #"{"path":"/fixture","entries":[{"path":"/fixture-other/private","size":2}]}"#,
      #"{"path":"/fixture","entries":[{"path":"/fixture/file","size":-2}]}"#,
    ] { XCTAssertThrowsError(try MoleDiskReport.parse(json, scope: scope)) }
    XCTAssertTrue(try MoleDiskReport.parse(#"{"path":"/fixture","entries":[]}"#, scope: scope).incomplete)
  }

  func testMoleInstallUsesOnlyReviewedFormulaAndNeverCallsClean() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    let commands = MoleCommands(executable: fixture.home.appendingPathComponent("mo"))
    let client = MoleToolClient(discoverMole: { FileManager.default.fileExists(atPath: fixture.home.appendingPathComponent("mo").path)
      ? fixture.home.appendingPathComponent("mo") : nil }, brew: URL(filePath: "/fixture/brew"), controlledEnvironment: { true },
      run: { _, args, _ in try await commands.run(args, scope: fixture.home) })
    let installed = try await client.install()
    XCTAssertTrue(installed.supported)
    _ = try await client.analyze(scope: fixture.home)
    _ = try await client.install() // An installed user CLI must not be upgraded.
    let calls = await commands.arguments
    XCTAssertEqual(calls.filter { $0.first == "install" }, [["install", "--formula", "homebrew/core/mole"]])
    XCTAssertTrue(calls.contains(["analyze", "--json", fixture.home.path]))
    XCTAssertFalse(calls.contains { $0.contains("clean") || $0.contains("purge") || $0.contains("upgrade") })
  }

  func testUnknownFormulaVersionAndEnvironmentOverridesCannotInstall() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    let commands = MoleCommands(executable: fixture.home.appendingPathComponent("mo"), formulaVersion: "2.0.0")
    for controlled in [true, false] {
      let client = MoleToolClient(discoverMole: { nil }, brew: URL(filePath: "/fixture/brew"),
        controlledEnvironment: { controlled }, run: { _, args, _ in try await commands.run(args, scope: fixture.home) })
      do { _ = try await client.install(); XCTFail("Unreviewed installs must fail") } catch {}
    }
    let calls = await commands.arguments
    XCTAssertFalse(calls.contains { $0.first == "install" })
    let missing = MoleToolClient(discoverMole: { nil }, brew: nil)
    do { _ = try await missing.install(); XCTFail("No package manager must not bootstrap one") } catch {}
  }

  func testPlanProtectsAllProjectCachesModelInstallersAndOutOfScopeItems() throws {
    let scope = URL(filePath: "/fixture")
    let items = [candidate("/fixture/Downloads/old.dmg", bytes: 2_000),
                 candidate("/fixture/Downloads/ollama-model.pkg", bytes: 50_000),
                 candidate("/fixture/Library/Developer/Xcode/DerivedData/Old", category: .xcode, bytes: 40_000),
                 candidate("/other/Downloads/old.dmg", bytes: 3_000)]
    let plan = DiskCleanupPlan.build(goal: try XCTUnwrap(DiskCleanupGoal.parse(DiskCleanupGoal.example)), scope: scope,
      scan: .init(candidates: items), occupancy: .init(entries: [], incomplete: false, measuredBytes: nil))
    XCTAssertEqual(plan.candidates.map(\.id), [items[0].id])
    XCTAssertEqual(plan.bytes, 2_000)
    XCTAssertEqual(plan.protectedCount, 3)
    XCTAssertGreaterThan(try XCTUnwrap(plan.goal.targetBytes), plan.bytes)
    let payload = try XCTUnwrap(DiskCleanupPlanning.messages(plan).last?["content"])
    for privateText in ["fixture", "old.dmg", "ollama", "帮我", "Downloads", "DerivedData"] { XCTAssertFalse(payload.contains(privateText)) }
    let valid = "{\"summary\":\"候选不足，仍需核对。\",\"ids\":[\"\(items[0].id.uuidString)\"]}"
    let ranked = try DiskCleanupPlanning.apply(valid, to: plan)
    XCTAssertTrue(ranked.usedAI)
    XCTAssertNotEqual(ranked.id, plan.id, "Changing a plan invalidates earlier approval")
    XCTAssertTrue(plan.acceptsApproval(planID: plan.id, ids: [items[0].id], scope: scope, at: plan.createdAt.addingTimeInterval(30)))
    XCTAssertFalse(plan.acceptsApproval(planID: plan.id, ids: [items[0].id], scope: scope, at: plan.createdAt.addingTimeInterval(301)))
    XCTAssertFalse(plan.acceptsApproval(planID: plan.id, ids: [items[0].id], scope: URL(filePath: "/different")))
    XCTAssertFalse(ranked.acceptsApproval(planID: plan.id, ids: [items[0].id], scope: scope))
    for invalid in [
      "{\"summary\":\"x\",\"ids\":[\"\(items[1].id.uuidString)\"]}",
      "{\"summary\":\"x\",\"ids\":[\"\(items[0].id.uuidString)\",\"\(items[0].id.uuidString)\"]}",
      #"{"summary":"x","ids":[],"command":"rm -rf /"}"#,
    ] { XCTAssertThrowsError(try DiskCleanupPlanning.apply(invalid, to: plan)) }
  }

  @MainActor func testAssistantRoutesGoalLocallyAndCapturesNotesBeforeCleanup() {
    let suite = "market-assistant-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = NativePreferencesStore(defaults: defaults)
    preferences.value.speechFeedback = false
    let assistant = NativeAssistantStore(preferences: preferences, keyProvider: { nil })
    var goals: [String] = [], captures: [WorkspaceCommand] = []
    assistant.performCleanupRequest = { goals.append($0); return .init(message: "plan") }
    assistant.performWorkspaceCommand = { captures.append($0); return .init(message: "captured") }
    assistant.submit(DiskCleanupGoal.example)
    XCTAssertEqual(goals, [DiskCleanupGoal.example])
    assistant.submit("记下 " + DiskCleanupGoal.example)
    assistant.submit("待办 " + DiskCleanupGoal.example)
    assistant.submit("不要清理磁盘")
    XCTAssertEqual(goals.count, 1)
    XCTAssertEqual(captures.count, 2)
    XCTAssertEqual(WorkspaceCommand.parse("打开应用市场"), .open(.market))
    XCTAssertEqual(WorkspaceCommand.parse(DiskCleanupGoal.example), .cleanup(DiskCleanupGoal.example))
    assistant.shutdown()
  }

  @MainActor func testStorePlansWithoutSelectingAndOnlyApprovedIDsReachTrash() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    try fixture.oldInstaller("old.dmg")
    let mole = MarketMoleFixture(scope: fixture.home)
    let store = ApplicationMarketStore(mole: mole, scanner: fixture.scanner(), scope: fixture.home)
    let observer = UUID()
    store.activate(observer)
    try await idle(store)
    XCTAssertTrue(store.requestCleanup(DiskCleanupGoal.example))
    try await idle(store)
    let plan = try XCTUnwrap(store.plan)
    let id = try XCTUnwrap(plan.candidates.first?.id)
    XCTAssertTrue(store.selection.isEmpty)
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    store.moveToTrash(planID: UUID(), ids: [id])
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    store.moveToTrash(planID: plan.id, ids: [UUID()])
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    store.moveToTrash(planID: plan.id, ids: [id])
    try await idle(store)
    XCTAssertTrue(fixture.exists("Trash/old.dmg"))
    XCTAssertNil(store.plan)
    XCTAssertTrue(store.feedback.contains("1"))
    store.moveToTrash(planID: plan.id, ids: [id])
    XCTAssertFalse(store.isBusy)
    store.deactivate(observer)
  }

  @MainActor func testQuickCommandsForwardTheSameGoalWithoutInstallingOrDeleting() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    let workspace = WorkspaceStore(url: fixture.home.appendingPathComponent("workspace.json"),
      notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    let commands = WorkspaceCommands(store: workspace)
    XCTAssertFalse(commands.execute(.cleanup(DiskCleanupGoal.example)))
    let mole = MarketMoleFixture(scope: fixture.home)
    let market = ApplicationMarketStore(mole: mole, scanner: fixture.scanner(), scope: fixture.home)
    commands.requestCleanup = { market.requestCleanup($0) }
    var destinations: [DemoModule] = []
    commands.navigate = { destinations.append($0) }
    commands.query = DiskCleanupGoal.example
    XCTAssertTrue(commands.submit())
    XCTAssertEqual(destinations, [.market])
    XCTAssertEqual(market.draft, DiskCleanupGoal.example)
    XCTAssertNil(market.plan, "Scanning starts only when the market is presented")
    let installs = await mole.installs
    XCTAssertEqual(installs, 0)
    _ = await workspace.flush()
  }

  @MainActor func testCanceledLateAIAndScopeChangesCannotReplaceThePlan() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    try fixture.oldInstaller("old.dmg")
    let delayed = MarketCompletion()
    let store = ApplicationMarketStore(mole: MarketMoleFixture(scope: fixture.home), scanner: fixture.scanner(), scope: fixture.home,
      completion: { _, _ in await delayed.wait() })
    let observer = UUID()
    store.activate(observer)
    try await idle(store)
    store.requestCleanup(DiskCleanupGoal.example)
    try await idle(store)
    store.analyzeWithAI(apiKey: "fixture-only")
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !(await delayed.started), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    store.cancel()
    store.changeScope(fixture.home.appendingPathComponent("Downloads"))
    await delayed.finish()
    try await Task.sleep(for: .milliseconds(20))
    XCTAssertNil(store.plan)
    XCTAssertEqual(store.phase, .idle)
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    store.deactivate(observer)
  }

  @MainActor func testMoleFailureStillProducesAnHonestLocalPlanAndNoSelection() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    try fixture.oldInstaller("old.dmg")
    let store = ApplicationMarketStore(mole: FailingMole(), scanner: fixture.scanner(), scope: fixture.home)
    let observer = UUID()
    store.activate(observer)
    try await idle(store)
    store.requestCleanup(DiskCleanupGoal.example)
    try await idle(store)
    XCTAssertEqual(store.plan?.candidates.count, 1)
    XCTAssertEqual(store.plan?.occupancy.incomplete, true)
    XCTAssertTrue(store.selection.isEmpty)
    XCTAssertFalse(store.feedback.isEmpty)
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    store.deactivate(observer)
  }

  @MainActor func testAIRefinementDoesNotSelectOrExecuteAndAnotherWindowKeepsTheStoreActive() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    try fixture.oldInstaller("old.dmg")
    let store = ApplicationMarketStore(mole: MarketMoleFixture(scope: fixture.home), scanner: fixture.scanner(), scope: fixture.home,
      completion: { messages, _ in
        let data = Data((messages.last?["content"] ?? "").utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidate = (json?["candidates"] as? [[String: Any]])?.first?["id"] as? String ?? ""
        return "{\"summary\":\"仍需核对，容量不足。\",\"ids\":[\"\(candidate)\"]}"
      })
    let first = UUID(), second = UUID()
    store.activate(first); store.activate(second)
    try await idle(store)
    store.deactivate(first)
    store.requestCleanup(DiskCleanupGoal.example)
    try await idle(store)
    let oldID = try XCTUnwrap(store.plan?.id)
    store.analyzeWithAI(apiKey: "fixture-only")
    try await idle(store)
    XCTAssertEqual(store.plan?.usedAI, true)
    XCTAssertNotEqual(store.plan?.id, oldID)
    XCTAssertTrue(store.selection.isEmpty)
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    if let plan = store.plan {
      let host = NSHostingView(rootView: DiskCleanupPlanView(plan: plan, store: store).frame(width: 380).padding(20)
        .background(Color(nsColor: .windowBackgroundColor)))
      host.frame = NSRect(x: 0, y: 0, width: 420, height: 650)
      host.layoutSubtreeIfNeeded(); host.frame.size = host.fittingSize; host.layoutSubtreeIfNeeded()
      XCTAssertEqual(host.frame.width, 420, accuracy: 1)
      if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_MARKET_DIR"] {
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(to: URL(filePath: directory).appendingPathComponent("market-plan.png"))
      }
    }
    store.deactivate(second)
  }

  @MainActor func testMarketRendersNarrowAndWideWithoutStartingInstallation() async throws {
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    let mole = MarketMoleFixture(scope: fixture.home)
    let store = ApplicationMarketStore(mole: mole, scanner: fixture.scanner(), scope: fixture.home)
    for width in [380, 760] {
      for dark in [false, true] {
        let content = ApplicationMarketView(store: store).frame(width: CGFloat(width), height: 820)
          .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 820)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_MARKET_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("market-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
    let installs = await mole.installs
    XCTAssertEqual(installs, 0)
  }

  func testRealInstalledMoleReadOnlyOnFixtureWhenRequested() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_INSTALLED_MOLE"] == "1" else { throw XCTSkip("Opt-in real CLI check") }
    let fixture = try MarketFixture()
    defer { fixture.remove() }
    try fixture.oldInstaller("old.dmg")
    let client = MoleToolClient()
    let installation = try await client.inspect()
    XCTAssertTrue(installation.supported)
    let report = try await client.analyze(scope: fixture.home)
    XCTAssertTrue(report.entries.contains { $0.name == "Downloads" })
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    print("Mole \(installation.version ?? "unknown"): \(report.entries.count) entries, incomplete=\(report.incomplete)")
  }

  private func candidate(_ path: String, category: CleanupCategory = .installers, bytes: UInt64) -> CleanupCandidate {
    .init(id: UUID(), url: URL(filePath: path), category: category, bytes: bytes, fingerprint: "fixture")
  }

  @MainActor private func idle(_ store: ApplicationMarketStore) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while store.isBusy, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    XCTAssertFalse(store.isBusy)
  }
}

private struct MarketFixture: Sendable {
  let home: URL
  let now = Date().addingTimeInterval(30 * 86_400)
  init() throws {
    home = FileManager.default.temporaryDirectory.appendingPathComponent("augma-market-" + UUID().uuidString).resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: home.appendingPathComponent("Trash"), withIntermediateDirectories: true)
  }
  func oldInstaller(_ name: String) throws {
    let target = home.appendingPathComponent("Downloads/" + name)
    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 1, count: 4_096).write(to: target)
  }
  func scanner() -> SystemCleanupScanner {
    let destination = home.appendingPathComponent("Trash"), current = now
    return SystemCleanupScanner(home: home, now: { current }, trash: {
      try FileManager.default.moveItem(at: $0, to: destination.appendingPathComponent($0.lastPathComponent))
    })
  }
  func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: home.appendingPathComponent(path).path) }
  func remove() { try? FileManager.default.removeItem(at: home) }
}

private actor MoleCommands {
  let executable: URL
  let formulaVersion: String
  var arguments: [[String]] = []
  init(executable: URL, formulaVersion: String = "1.64.0") { self.executable = executable; self.formulaVersion = formulaVersion }
  func run(_ args: [String], scope: URL) throws -> CleanupCommandResult {
    arguments.append(args)
    if args.first == "info" { return .init(status: 0, output: "{\"formulae\":[{\"name\":\"mole\",\"full_name\":\"mole\",\"tap\":\"homebrew/core\",\"versions\":{\"stable\":\"\(formulaVersion)\"}}]}") }
    if args.first == "install" { try Data().write(to: executable); return .init(status: 0, output: "installed") }
    if args == ["--version"] { return .init(status: 0, output: "Mole version 1.64.0") }
    return .init(status: 0, output: "{\"path\":\"\(scope.path)\",\"scan_status\":\"complete\",\"entries\":[]}")
  }
}

private actor MarketMoleFixture: MoleToolProviding {
  let scope: URL
  var installs = 0
  init(scope: URL) { self.scope = scope }
  func inspect() -> MoleInstallation { .init(version: "1.64.0", homebrewAvailable: true) }
  func install() -> MoleInstallation { installs += 1; return inspect() }
  func analyze(scope: URL) -> MoleDiskReport { .init(entries: [], incomplete: false, measuredBytes: 4_096) }
}

private actor MarketCompletion {
  var started = false
  var continuation: CheckedContinuation<String, Never>?
  func wait() async -> String { started = true; return await withCheckedContinuation { continuation = $0 } }
  func finish() { continuation?.resume(returning: #"{"summary":"late","ids":[]}"#); continuation = nil }
}

private struct FailingMole: MoleToolProviding {
  func inspect() -> MoleInstallation { .init(version: "1.64.0", homebrewAvailable: true) }
  func install() -> MoleInstallation { inspect() }
  func analyze(scope: URL) throws -> MoleDiskReport { throw MoleToolError.invalidReport }
}
