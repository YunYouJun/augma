import Foundation
import AppKit
import MCP
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

final class ACPFramingTests: XCTestCase {
  func testFragmentedUnicodeAndMultipleFrames() throws {
    var framer = ACPFramer()
    let data = Data("{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"result\":\"天气\"}\n{\"jsonrpc\":\"2.0\",\"id\":\"2\",\"result\":{}}\n".utf8)
    var frames: [ACPValue] = []
    for byte in data { frames += try framer.append(Data([byte])) }
    XCTAssertEqual(frames.count, 2)
    XCTAssertEqual(frames[0]["result"].string, "天气")
  }
  func testRejectsLogsMalformedAndOversizedFrames() {
    for data in [Data("log output\n".utf8), Data("{}\n".utf8), Data(repeating: 65, count: ACPFramer.limit + 1)] {
      var framer = ACPFramer()
      XCTAssertThrowsError(try framer.append(data))
    }
  }
  func testMigrationPreservesExplicitOffAndOnWithoutWritingKeys() {
    let name = "AugmaRuntimeTests.\(UUID())", defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    XCTAssertEqual(AssistantRuntimeSettings.backend(defaults), .dsh)
    XCTAssertNil(defaults.object(forKey: DeepSeekSettings.enabledKey))
    defaults.set(false, forKey: DeepSeekSettings.enabledKey)
    XCTAssertEqual(AssistantRuntimeSettings.backend(defaults), .deepseek)
    defaults.set(true, forKey: DeepSeekSettings.enabledKey)
    XCTAssertEqual(AssistantRuntimeSettings.backend(defaults), .deepseek)
    defaults.set("dsh", forKey: AssistantRuntimeSettings.backendKey)
    XCTAssertEqual(AssistantRuntimeSettings.backend(defaults), .dsh)
    XCTAssertTrue(defaults.bool(forKey: DeepSeekSettings.enabledKey))
  }
  func testExplicitCompositionContainsOnlyReviewedServices() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Augma Profile \(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = MagpieModel(id: "model/one", name: "Model", contextWindow: 128000, maxTokens: 4096, reasoning: ["low"])
    try AugmaDSHProfile.write(home: root, sessions: root.appendingPathComponent("sessions"), catalog: .init(port: 3425, models: [model]), model: model.id)
    let data = try Data(contentsOf: root.appendingPathComponent("profiles/augma/cordis.patch.yml"))
    let rows = try JSONDecoder().decode(ACPValue.self, from: data).array[0]["insert"].array
    let names = Set(rows.compactMap { $0["id"].string })
    XCTAssertTrue(names.contains("acp"))
    XCTAssertTrue(names.contains("compaction-basic"))
    XCTAssertTrue(names.isDisjoint(with: ["subprocess", "tool-bash", "tool-fs", "tool-web", "skill", "subagent", "settings", "credentials", "hmr", "plugin-manager"]))
    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("magpie-augma"))
    XCTAssertThrowsError(try AugmaDSHProfile.write(home: root, sessions: root, catalog: .init(port: 3425, models: [model]), model: "removed"))
  }
}

@MainActor
final class ACPConnectionTests: XCTestCase {
  private func fixture() throws -> (ACPConnection, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Augma ACP \(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let script = directory.appendingPathComponent("fake agent.py")
    try #"""
    import json,sys,time
    first=None
    for line in sys.stdin:
      message=json.loads(line)
      method=message.get('method')
      if method=='first': first=message; continue
      if method=='second':
        for item in [message,first]:
          sys.stdout.write(json.dumps({'jsonrpc':'2.0','id':item['id'],'result':item['method']})+'\n'); sys.stdout.flush()
      elif method=='permission':
        sys.stdout.write(json.dumps({'jsonrpc':'2.0','id':7,'method':'session/request_permission','params':{'sessionId':'fake'}})+'\n'); sys.stdout.flush()
        response=json.loads(sys.stdin.readline())
        print(json.dumps({'jsonrpc':'2.0','id':message['id'],'result':response['result']}),flush=True)
      elif method=='hang': pass
      elif method=='crash': sys.exit(2)
      elif method=='bad': print('not json',flush=True)
    """#.write(to: script, atomically: true, encoding: .utf8)
    let client = ACPConnection()
    try client.start(executable: URL(fileURLWithPath: "/usr/bin/python3"), arguments: [script.path], directory: directory,
                     environment: ["PATH": "/usr/bin:/bin"])
    return (client, directory)
  }
  func testOutOfOrderResponsesAndBidirectionalRequest() async throws {
    let (client, dir) = try fixture()
    defer { client.stop(); try? FileManager.default.removeItem(at: dir) }
    async let first = client.request("first", .object([:]))
    try await Task.sleep(for: .milliseconds(30))
    let second = try await client.request("second", .object([:]))
    XCTAssertEqual(second.string, "second")
    let firstValue = try await first
    XCTAssertEqual(firstValue.string, "first")
    client.incomingRequest = { _, _ in .object(["outcome": .object(["outcome": .string("cancelled")])]) }
    let result = try await client.request("permission", .object([:]))
    XCTAssertEqual(result["outcome"]["outcome"].string, "cancelled")
  }
  func testTimeoutCancellationAndCrashSettleRequests() async throws {
    let (client, dir) = try fixture()
    defer { client.stop(); try? FileManager.default.removeItem(at: dir) }
    do { _ = try await client.request("hang", .object([:]), timeout: 0.05); XCTFail("must time out") }
    catch { XCTAssertTrue(error is AssistantRuntimeError) }
    let pending = Task { try await client.request("hang", .object([:])) }
    try await Task.sleep(for: .milliseconds(20)); pending.cancel()
    do { _ = try await pending.value; XCTFail("must cancel") } catch { XCTAssertTrue(error is CancellationError) }
    do { _ = try await client.request("crash", .object([:])); XCTFail("must disconnect") }
    catch { XCTAssertTrue(error is AssistantRuntimeError) }
    XCTAssertFalse(client.isRunning)
  }
  func testMalformedOutputDisconnects() async throws {
    let (client, dir) = try fixture()
    defer { client.stop(); try? FileManager.default.removeItem(at: dir) }
    do { _ = try await client.request("bad", .object([:])); XCTFail("must reject protocol noise") }
    catch { XCTAssertTrue(error is AssistantRuntimeError) }
    XCTAssertFalse(client.isRunning)
  }
}

@MainActor
final class NativeToolBoundaryTests: XCTestCase {
  func testHTTPAuthorizationSessionIsolationAndRevocation() async throws {
    let scope = NativeToolScope(), other = NativeToolScope()
    var opened = 0
    scope.openPanel = { _ in opened += 1; return .init(message: "Opened") }
    let bridge = NativeMCPBridge(scope: scope), second = NativeMCPBridge(scope: other)
    let descriptor = try await bridge.start(), otherDescriptor = try await second.start()
    defer { bridge.stop(); second.stop() }
    let url = try XCTUnwrap(URL(string: try XCTUnwrap(descriptor["url"].string)))
    let bearer = try XCTUnwrap(descriptor["headers"].array.first?["value"].string)
    func send(_ method: String, params: ACPValue = .object([:]), auth: String?, origin: String? = nil) async throws -> (Int, ACPValue) {
      var request = URLRequest(url: url, timeoutInterval: 3)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
      request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
      request.setValue(auth, forHTTPHeaderField: "Authorization")
      request.setValue(origin, forHTTPHeaderField: "Origin")
      request.httpBody = try JSONEncoder().encode(ACPValue.object([
        "jsonrpc": .string("2.0"), "id": .number(1), "method": .string(method), "params": params]))
      let (data, response) = try await URLSession.shared.data(for: request)
      return ((response as? HTTPURLResponse)?.statusCode ?? 0, (try? JSONDecoder().decode(ACPValue.self, from: data)) ?? .null)
    }
    for auth in [nil, "Bearer invalid", otherDescriptor["headers"].array.first?["value"].string] {
      let result = try await send("tools/list", auth: auth)
      XCTAssertEqual(result.0, 403)
    }
    let browser = try await send("tools/list", auth: bearer, origin: "https://example.com")
    XCTAssertEqual(browser.0, 403)
    let list = try await send("tools/list", auth: bearer)
    XCTAssertEqual(list.0, 200)
    XCTAssertEqual(list.1["result"]["tools"].array.count, 3)
    XCTAssertTrue(list.1["result"]["tools"].array.allSatisfy { $0["outputSchema"].object != nil })
    let call = ACPValue.object(["name": .string("open_panel"), "arguments": .object(["panel": .string("map")])])
    let inactive = try await send("tools/call", params: call, auth: bearer)
    XCTAssertEqual(inactive.1["result"]["isError"], .bool(true))
    scope.begin()
    let result = try await send("tools/call", params: call, auth: bearer)
    XCTAssertEqual(result.1["result"]["structuredContent"]["message"].string, "Opened")
    scope.revoke()
    let revoked = try await send("tools/call", params: call, auth: bearer)
    XCTAssertEqual(revoked.1["result"]["isError"], .bool(true))
    XCTAssertEqual(opened, 1)
  }

  func testRevokedAndInvalidCallsDoNotOpenPanelsAndNoDuplicateEffects() async throws {
    let scope = NativeToolScope()
    var opened = 0
    scope.openPanel = { _ in opened += 1; return .init(message: "opened") }
    do { _ = try await scope.call(name: "open_panel", arguments: ["panel": .string("map")]); XCTFail() } catch { }
    scope.begin()
    for args: [String: Value] in [["panel": .string("shell")], ["panel": .string("map"), "path": .string("/tmp")]] {
      do { _ = try await scope.call(name: "open_panel", arguments: args); XCTFail() } catch { }
    }
    XCTAssertEqual(opened, 0)
    _ = try await scope.call(name: "open_panel", arguments: ["panel": .string("map")])
    do { _ = try await scope.call(name: "open_panel", arguments: ["panel": .string("map")]); XCTFail() } catch { }
    scope.revoke()
    do { _ = try await scope.call(name: "open_panel", arguments: ["panel": .string("browser")]); XCTFail() } catch { }
    XCTAssertEqual(opened, 1)
    XCTAssertEqual(Set(NativeToolScope.tools.map(\.name)), ["system_summary", "application_usage", "open_panel"])
  }
}

@MainActor
final class DSHConfigurationTests: XCTestCase {
  func testPermissionDenialAndLateApprovalAfterCancellation() async throws {
    let name = "AugmaPermission.\(UUID())", defaults = UserDefaults(suiteName: name)!
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Augma Permission \(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let agent = root.appendingPathComponent("agent fixture")
    try #"""
    #!/usr/bin/python3
    import json,sys,time
    if '--version' in sys.argv: print('0.2.0-rc.2');sys.exit(0)
    def out(x): print(json.dumps(dict(jsonrpc='2.0',**x)),flush=True)
    choices=[dict(id='model',name='Model',type='select',currentValue='["magpie","test"]',options=[dict(value='["magpie","test"]',name='Test')])]
    pending=None;serial=0
    for line in sys.stdin:
      m=json.loads(line);method=m.get('method');mid=m.get('id');p=m.get('params',{})
      if method=='initialize': out(dict(id=mid,result=dict(protocolVersion=1,agentInfo=dict(name='deepseek-harness-acp'),agentCapabilities=dict(mcpCapabilities=dict(http=True),sessionCapabilities=dict(close={},resume={})))))
      elif method=='session/new':
        serial+=1
        if serial>1: time.sleep(.2)
        out(dict(id=mid,result=dict(sessionId=str(serial),configOptions=choices)))
      elif method=='session/set_config_option': out(dict(id=mid,result=dict(configOptions=choices)))
      elif method=='session/prompt':
        pending=(mid,p['sessionId'])
        out(dict(id='permission',method='session/request_permission',params=dict(sessionId=p['sessionId'],options=[dict(kind='allow_once',optionId='yes'),dict(kind='reject_once',optionId='no')])))
      elif mid=='permission' and pending:
        approved=m['result']['outcome'].get('optionId')=='yes'
        out(dict(method='session/update',params=dict(sessionId=pending[1],update=dict(sessionUpdate='agent_message_chunk',content=dict(type='text',text='allowed' if approved else 'denied')))))
        out(dict(id=pending[0],result=dict(stopReason='end_turn')));pending=None
      elif method=='session/cancel' and pending:
        out(dict(id=pending[0],result=dict(stopReason='cancelled')));pending=None
      elif method=='session/close': out(dict(id=mid,result={}))
    """#.write(to: agent, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: agent.path)
    defaults.set(agent.path, forKey: AssistantRuntimeSettings.executableKey)
    defaults.set("test", forKey: AssistantRuntimeSettings.modelKey)
    let runtime = NativeAssistantRuntime(defaults: defaults, supportRoot: root.appendingPathComponent("state"), loadCatalog: {
      .init(port: 3425, models: [.init(id: "test", name: "Test", contextWindow: 128000, maxTokens: 4096, reasoning: [])])
    })
    defer { runtime.shutdown(); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
    let owner = UUID(), scope = NativeToolScope()
    let messages = [["role": "system", "content": "fixture"], ["role": "user", "content": "fixture"]]
    func waitForPermission() async throws -> AssistantPermission {
      let deadline = Date().addingTimeInterval(3)
      while runtime.permission == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
      return try XCTUnwrap(runtime.permission)
    }
    let denied = Task { try await runtime.complete(messages: messages, owner: owner, scope: scope, testing: true) }
    let permission = try await waitForPermission()
    permission.resolve(false)
    let reply = try await denied.value
    XCTAssertEqual(reply, "denied")
    XCTAssertNil(runtime.permission)
    let existingPID = runtime.processIdentifier
    let discovery = Task { try await runtime.discoverOptions() }
    try await Task.sleep(for: .milliseconds(50))
    discovery.cancel()
    do { _ = try await discovery.value; XCTFail("Discovery was cancelled") } catch { }
    XCTAssertEqual(runtime.processIdentifier, existingPID, "Cancelling an unadmitted session must preserve other windows")
    let cancelled = Task { try await runtime.complete(messages: messages, owner: owner, scope: scope, testing: true) }
    let late = try await waitForPermission()
    runtime.cancel(owner: owner); cancelled.cancel()
    late.resolve(true)
    do { _ = try await cancelled.value; XCTFail("Late approval cannot revive a cancelled task") } catch { }
    XCTAssertNil(runtime.permission)
    XCTAssertFalse(scope.active)
    await runtime.shutdownAndWait()
  }

  func testMissingBrokenAndUnverifiedExecutablesFailWithoutFallback() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Augma Launch \(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for (name, script, expected) in [
      ("absent", nil, AssistantRuntimeError.missingRuntime),
      ("broken shim", "#!/bin/sh\nexit 2\n", .launchFailed),
      ("future version", "#!/bin/sh\nprintf '9.9.9\\n'\n", .unsupportedVersion),
    ] {
      let file = root.appendingPathComponent(name)
      if let script {
        try script.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
      }
      do { _ = try await DSHInstallation.resolve(path: file.path); XCTFail("Must not fall back to a different runtime") }
      catch { XCTAssertEqual(error as? AssistantRuntimeError, expected) }
    }
  }
  func testProviderErrorsAreClassifiedWithoutExposingRawContent() {
    for (message, expected) in [("401 secret-value", AssistantRuntimeError.authentication), ("429 secret-value", .quota), ("unknown secret-value", .taskFailed)] {
      let error = AssistantRuntimeError.remote(.object(["message": .string(message)]))
      XCTAssertEqual(error, expected)
      XCTAssertFalse(error.localizedDescription.contains("secret-value"))
    }
  }
  func testSettingsLayoutAtNarrowWidthWithLongPathInBothAppearances() throws {
    let name = "AugmaSettingsLayout.\(UUID())", defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("/Applications/A deliberately long path with spaces/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh", forKey: AssistantRuntimeSettings.executableKey)
    for width in [420, 540] {
      for dark in [false, true] {
        let view = AssistantSettingsView().defaultAppStorage(defaults)
          .frame(width: CGFloat(width), height: 620).background(Color(nsColor: .windowBackgroundColor))
          .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 620)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_ASSISTANT_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("assistant-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
  }
}

@MainActor
final class DSHLiveIntegrationTests: XCTestCase {
  func testRealSessionsResumeWithoutReplayAndCancellationStartsFresh() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["AUGMA_DSH_LIVE_TEST"] == "1", "Explicit live-test opt-in required")
    let name = "AugmaLifecycle.\(UUID())", defaults = UserDefaults(suiteName: name)!
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Augma Lifecycle \(UUID())")
    defaults.set("codex/gpt-6-luna", forKey: AssistantRuntimeSettings.modelKey)
    defaults.set("low", forKey: AssistantRuntimeSettings.reasoningKey)
    let runtime = NativeAssistantRuntime(defaults: defaults, supportRoot: root)
    defer { runtime.shutdown(); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
    let first = UUID(), second = UUID()
    func messages(_ content: String) -> [[String: String]] {
      [["role": "system", "content": "Reply with the requested single word only. Remember only the marker in this session."], ["role": "user", "content": content]]
    }
    _ = try await runtime.complete(messages: messages("My marker is amber. Reply amber."), owner: first, testing: true)
    _ = try await runtime.complete(messages: messages("My marker is silver. Reply silver."), owner: second, testing: true)
    let oldPID = runtime.processIdentifier
    runtime.shutdown(preserveIdle: true)
    try await Task.sleep(for: .seconds(3))
    let a = try await runtime.complete(messages: messages("What was my marker?"), owner: first, testing: true)
    let b = try await runtime.complete(messages: messages("What was my marker?"), owner: second, testing: true)
    XCTAssertTrue(a.lowercased().contains("amber"))
    XCTAssertTrue(b.lowercased().contains("silver"))
    XCTAssertNotEqual(oldPID, runtime.processIdentifier)
    let cancelledSession = runtime.sessionIdentifier(owner: first)
    let cancelled = Task { try await runtime.complete(messages: messages("Explain memory management in detail."), owner: first, testing: true) }
    try await Task.sleep(for: .milliseconds(100))
    cancelled.cancel(); runtime.cancel(owner: first)
    do { _ = try await cancelled.value; XCTFail("Cancelled task must not return a reply") } catch { }
    let next = try await runtime.complete(messages: messages("Reply fresh."), owner: first, testing: true)
    XCTAssertNotEqual(cancelledSession, runtime.sessionIdentifier(owner: first))
    XCTAssertFalse(next.isEmpty)
    print("AUGMA_LIVE_FRESH_REPLY", String(next.prefix(80)))
    print("AUGMA_LIVE_LIFECYCLE independentSessions=2 resumed=true cancellation=true freshSession=true")
    await runtime.shutdownAndWait()
  }

  func testRealMagpieToolLoopAndProcessCleanup() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["AUGMA_DSH_LIVE_TEST"] == "1", "Explicit opt-in: uses configured Magpie model quota and read-only system data")
    let name = "AugmaLiveTest.\(UUID())", defaults = UserDefaults(suiteName: name)!
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Augma Live \(UUID())")
    defaults.set("codex/gpt-6-luna", forKey: AssistantRuntimeSettings.modelKey)
    defaults.set("low", forKey: AssistantRuntimeSettings.reasoningKey)
    let runtime = NativeAssistantRuntime(defaults: defaults, supportRoot: root)
    defer { runtime.shutdown(); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
    let owner = UUID(), scope = NativeToolScope()
    var tools: [String] = []
    scope.onTool = { tools.append($0) }
    let start = Date()
    let answer = try await runtime.complete(messages: [
      ["role": "system", "content": "You are testing Augma. Read memory pressure and application memory using the native tools, then give one short sentence of advice based on the actual results. Do not open panels."],
      ["role": "user", "content": "Read memory pressure, inspect application usage, then advise whether I need to reduce memory use."],
    ], owner: owner, scope: scope, testing: true)
    XCTAssertTrue(scope.successfulTools.isSuperset(of: ["system_summary", "application_usage"]))
    XCTAssertFalse(answer.isEmpty)
    print("AUGMA_LIVE_EVIDENCE seconds=\(Date().timeIntervalSince(start)) tools=\(tools) replyCharacters=\(answer.count)")
    print("AUGMA_LIVE_TIMING startup=\(runtime.lastStartupSeconds) firstFeedback=\(runtime.lastFirstFeedbackSeconds ?? -1) task=\(runtime.lastTaskSeconds)")
    let pid = try XCTUnwrap(runtime.processIdentifier)
    let process = Process(), pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-p", String(pid), "-o", "pid=,pcpu=,rss=,etime="]
    process.standardOutput = pipe
    try process.run(); process.waitUntilExit()
    print("AUGMA_LIVE_PROCESS", String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    // Synthetic numeric business snapshot: no user files are scanned, selected or removed.
    let scan = CleanupScan(candidates: [CleanupCandidate(id: UUID(), url: URL(filePath: "/test/fixture.dmg"),
      category: .installers, bytes: 4_096, fingerprint: "fixture")])
    let cleanupMessages = try CleanupAdvice.messages(scan: scan, snapshot: SystemSnapshot(), locale: "en")
    let cleanupReply = try await runtime.complete(messages: cleanupMessages, owner: UUID(), testing: true)
    let advice = try CleanupAdvice.parse(cleanupReply, scan: scan, applicationIDs: [])
    XCTAssertFalse(advice.summary.isEmpty)
    print("AUGMA_LIVE_CLEANUP structuredAdvice=true syntheticSnapshot=true toolScope=none")
    runtime.shutdown()
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(kill(pid, 0), -1, "Only the runtime-owned process must exit")
  }
}
