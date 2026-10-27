import AppKit
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

final class SimulatorCleanupTests: XCTestCase {
  func testScanSeparatesDeviceDataFromSharedRuntimeAndPreservesUnknownSizes() async throws {
    let fixture = SimulatorFixture()
    await fixture.changeDevice(SimulatorFixture.qa) { $0.bytes = nil }
    let scan = try await client(fixture).scan()
    let qa = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
    let shared = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.sharedRuntime })
    let unused = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.unusedRuntime })
    XCTAssertEqual(qa.kind, .device)
    XCTAssertEqual(scan.items.first { $0.identifier == SimulatorFixture.active }?.deviceTypeIdentifier,
                   "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo",
                   "A renamed simulator must retain its real device type for icon selection")
    XCTAssertEqual(scan.items.first { $0.identifier == SimulatorFixture.active }?.modelIdentifier, "iPhone19,4")
    XCTAssertEqual(qa.modelIdentifier, "iPhone18,3")
    XCTAssertNil(qa.bytes, "Missing data size must remain unknown rather than appearing as zero")
    XCTAssertNotNil(qa.lastUsedAt)
    XCTAssertTrue(scan.incomplete)
    XCTAssertEqual(shared.dependentDeviceCount, 2)
    XCTAssertFalse(shared.canDelete)
    XCTAssertNotNil(shared.restriction)
    XCTAssertEqual(unused.bytes, 8_000_000_000)
    XCTAssertTrue(unused.canDelete)
    XCTAssertEqual(scan.runtimeBytes, 16_000_000_000)
    let calls = await fixture.calls
    XCTAssertTrue(calls.allSatisfy { $0.executable == "/usr/bin/xcrun" })
    XCTAssertEqual(Set(calls.map(\.arguments)), Set([
      ["simctl", "list", "devicetypes", "--json"],
      ["simctl", "list", "devices", "--json"], ["simctl", "runtime", "list", "--json"],
    ]))
  }

  func testModelCatalogRefreshesPerScanAndIsReusedDuringExecutionChecks() async throws {
    let fixture = SimulatorFixture()
    let tool = client(fixture)
    let first = try await tool.scan()
    XCTAssertEqual(first.items.first { $0.identifier == SimulatorFixture.active }?.modelIdentifier, "iPhone19,4")
    await fixture.overrideDeviceTypes(#"{"devicetypes":[{"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-Duo","modelIdentifier":"iPhone18,1"},{"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17","modelIdentifier":"iPhone18,3"}]}"#)
    let second = try await tool.scan()
    XCTAssertEqual(second.items.first { $0.identifier == SimulatorFixture.active }?.modelIdentifier, "iPhone18,1")
    let qa = try XCTUnwrap(second.items.first { $0.identifier == SimulatorFixture.qa })
    let receipt = try await tool.delete(scanID: second.id, ids: [qa.id])
    XCTAssertEqual(receipt.results.first?.status, .deleted)
    let calls = await fixture.calls
    XCTAssertEqual(calls.filter { $0.arguments == ["simctl", "list", "devicetypes", "--json"] }.count, 2,
                   "Revalidation must reuse the catalog, rather than spawning once for each item or check")
  }

  func testMissingInvalidAndUnknownModelMetadataDoesNotWeakenDeletionProtection() async throws {
    let oversizedCatalog = String(decoding: try JSONSerialization.data(withJSONObject: ["devicetypes": Array(repeating:
      ["identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo", "modelIdentifier": "iPhone19,4"], count: 4_001)]), as: UTF8.self)
    let scenarios: [(String, Int32, String?)] = [
      ("not JSON", 0, nil),
      (#"{"devicetypes":[{"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"}]}"#, 0, nil),
      (#"{"devicetypes":[{"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-Duo","modelIdentifier":"/private/model"}]}"#, 0, nil),
      (#"{"devicetypes":[]}"#, 1, nil),
      (oversizedCatalog, 0, nil),
      (#"{"devicetypes":[{"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-Duo","modelIdentifier":"FuturePhone99,1"}]}"#, 0, "FuturePhone99,1"),
    ]
    for (catalog, status, expectedModel) in scenarios {
      let fixture = SimulatorFixture()
      await fixture.overrideDeviceTypes(catalog, status: status)
      await fixture.changeDevice(SimulatorFixture.active) { $0.state = "Booted" }
      let tool = client(fixture)
      let scan = try await tool.scan()
      let active = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.active })
      let qa = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
      XCTAssertEqual(active.modelIdentifier, expectedModel)
      XCTAssertEqual(scan.deviceBytes, 8_500_000_000, "Missing artwork metadata must not zero known storage sizes")
      XCTAssertTrue(scan.warnings.contains(String(localized: "部分设备型号无法读取，已使用通用图标。")))
      XCTAssertFalse(active.canDelete)
      XCTAssertTrue(scan.items.filter { $0.kind == .runtime }.allSatisfy { !$0.canDelete })
      let receipt = try await tool.delete(scanID: scan.id, ids: [qa.id])
      XCTAssertEqual(receipt.results.first?.status, .deleted, "Icon fallback must not block a separately confirmed, valid device operation")
    }
  }

  func testModelCatalogCancellationPropagatesWithoutContinuingTheScan() async {
    let fixture = SimulatorFixture()
    await fixture.cancelDeviceTypesRead()
    do { _ = try await client(fixture).scan(); XCTFail("Cancellation must not be mistaken for unavailable icon metadata") }
    catch is CancellationError {}
    catch { XCTFail("Unexpected cancellation result: \(error)") }
    let calls = await fixture.calls
    XCTAssertEqual(calls.map(\.arguments), [["simctl", "list", "devicetypes", "--json"]])
  }

  func testRunningAndUnknownDevicesProtectEveryRuntimeAndCannotBeSelectedForDeletion() async throws {
    for state in ["Booted", "Booting", "Unknown"] {
      let fixture = SimulatorFixture()
      await fixture.changeDevice(SimulatorFixture.active) { $0.state = state }
      let scan = try await client(fixture).scan()
      let active = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.active })
      XCTAssertFalse(active.canDelete)
      XCTAssertTrue(scan.items.filter { $0.kind == .runtime }.allSatisfy { !$0.canDelete },
                    "Runtime removal may restart simulator services, so an unrelated active device also protects it")
    }
  }

  func testMalformedInventoriesAndInvalidIdentifiersNeverProduceExecutablePlans() async throws {
    for invalid in ["not JSON", #"{"devices":[]}"#, #"{"devices":{"invalid-runtime":[{"name":"private","state":"Shutdown"}]}}"#,
                    #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-1":[{"udid":"all","name":"private","state":"Shutdown","isAvailable":true}]}}"#] {
      let fixture = SimulatorFixture()
      await fixture.overrideDevices(invalid)
      do { _ = try await client(fixture).scan(); XCTFail("Malformed inventory must fail closed") } catch {}
      let deletes = await fixture.deletionCalls
      XCTAssertTrue(deletes.isEmpty)
    }
    let fixture = SimulatorFixture()
    await fixture.overrideRuntimes(#"{"all":{"identifier":"all","state":"Ready","deletable":true}}"#)
    do { _ = try await client(fixture).scan(); XCTFail("Special simctl aliases cannot become item identifiers") } catch {}
  }

  func testMissingAvailabilityAndRuntimeCapabilityMetadataRemainReadOnly() async throws {
    let fixture = SimulatorFixture()
    await fixture.changeDevice(SimulatorFixture.qa) { $0.available = nil }
    await fixture.changeRuntime(SimulatorFixture.unusedRuntime) { $0.deletable = nil }
    let scan = try await client(fixture).scan()
    for identifier in [SimulatorFixture.qa, SimulatorFixture.unusedRuntime] {
      XCTAssertFalse(try XCTUnwrap(scan.items.first { $0.identifier == identifier }).canDelete)
    }
    let unknown = SimulatorFixture()
    await unknown.changeRuntime(SimulatorFixture.unusedRuntime) { $0.state = "FutureState" }
    let unknownScan = try await client(unknown).scan()
    XCTAssertFalse(try XCTUnwrap(unknownScan.items.first { $0.identifier == SimulatorFixture.unusedRuntime }).canDelete)
  }

  func testExpiredWrongAndSupersededScanIDsAndExtraItemsCannotReachDelete() async throws {
    for scenario in 0..<4 {
      let fixture = SimulatorFixture()
      let clock = SimulatorFixtureClock()
      let tool = client(fixture, clock: clock)
      let scan = try await tool.scan()
      let qa = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
      var id = scan.id
      var ids: Set<String> = [qa.id]
      switch scenario {
      case 0: id = UUID()
      case 1: clock.advance(301)
      case 2: _ = try await tool.scan()
      default: ids.insert("device:" + UUID().uuidString)
      }
      do { _ = try await tool.delete(scanID: id, ids: ids); XCTFail("Approval must bind the current, unexpired inventory") } catch {}
      let deletes = await fixture.deletionCalls
      XCTAssertTrue(deletes.isEmpty)
    }
  }

  func testStateAndIdentityChangesAfterReviewCannotReachDelete() async throws {
    for scenario in 0..<3 {
      let fixture = SimulatorFixture()
      let tool = client(fixture)
      let scan = try await tool.scan()
      let qa = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
      await fixture.changeDevice(SimulatorFixture.qa) {
        switch scenario {
        case 0: $0.state = "Booted"
        case 1: $0.name = "A different test environment"
        default: $0.bytes = 7_000_000_000
        }
      }
      do {
        let receipt = try await tool.delete(scanID: scan.id, ids: [qa.id])
        XCTAssertTrue(receipt.results.allSatisfy { $0.status != .deleted })
      } catch {}
      let deletes = await fixture.deletionCalls
      XCTAssertTrue(deletes.isEmpty)
    }
  }

  func testApprovalExpiringDuringRevalidationSkipsBeforeInvokingDelete() async throws {
    for read in 1...2 {
      let fixture = SimulatorFixture()
      let clock = SimulatorFixtureClock()
      let tool = client(fixture, clock: clock)
      let scan = try await tool.scan()
      let qa = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
      // Cover expiry during the initial validation and during the per-item inventory read.
      await fixture.afterRuntimeRead(read) { clock.advance(301) }
      let receipt = try await tool.delete(scanID: scan.id, ids: [qa.id])
      XCTAssertEqual(receipt.results.count, 1)
      XCTAssertEqual(receipt.results.first?.status, .skipped,
                     "Inventory reads must not extend the lifetime of an earlier confirmation")
      let deletes = await fixture.deletionCalls
      XCTAssertTrue(deletes.isEmpty)
    }
  }

  func testNewRuntimeDependencyOrUnrelatedRunningDeviceAfterReviewPreventsRemoval() async throws {
    for scenario in 0..<2 {
      let fixture = SimulatorFixture()
      let tool = client(fixture)
      let scan = try await tool.scan()
      let runtime = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.unusedRuntime })
      XCTAssertTrue(runtime.canDelete)
      await fixture.changeDevice(SimulatorFixture.qa) {
        if scenario == 0 { $0.runtime = SimulatorFixture.unusedIdentifier }
        else { $0.state = "Booted" }
      }
      do {
        let receipt = try await tool.delete(scanID: scan.id, ids: [runtime.id], runtimeScopeAcknowledged: true)
        XCTAssertTrue(receipt.results.allSatisfy { $0.status != .deleted })
      } catch {}
      let deletes = await fixture.deletionCalls
      XCTAssertTrue(deletes.isEmpty)
    }
  }

  func testProtectedRuntimeCannotBeDeletedInTheSameBatchAsItsDependentDevices() async throws {
    let fixture = SimulatorFixture()
    let tool = client(fixture)
    let scan = try await tool.scan()
    let shared = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.sharedRuntime })
    let ids = Set(scan.items.filter { $0.kind == .device }.map(\.id)).union([shared.id])
    do {
      _ = try await tool.delete(scanID: scan.id, ids: ids, runtimeScopeAcknowledged: true)
      XCTFail("Dependencies require a new scan after device deletion")
    } catch {}
    let deletes = await fixture.deletionCalls
    XCTAssertTrue(deletes.isEmpty)
  }

  func testEachItemIsRecheckedWhenTheNextDeviceStartsDuringTheBatch() async throws {
    let fixture = SimulatorFixture()
    let tool = client(fixture)
    let scan = try await tool.scan()
    await fixture.bootDeviceAfterFirstDeletion(SimulatorFixture.qa)
    let receipt = try await tool.delete(scanID: scan.id, ids: Set(scan.items.filter { $0.kind == .device }.map(\.id)))
    XCTAssertEqual(receipt.results.first { $0.item.identifier == SimulatorFixture.active }?.status, .deleted)
    XCTAssertEqual(receipt.results.first { $0.item.identifier == SimulatorFixture.qa }?.status, .skipped)
    let deletes = await fixture.deletionCalls
    XCTAssertEqual(deletes, [["simctl", "delete", SimulatorFixture.active]])
  }

  func testOnlySelectedDeviceIsDeletedWithFixedArgumentsAndApprovalIsSingleUse() async throws {
    let fixture = SimulatorFixture()
    let tool = client(fixture)
    let scan = try await tool.scan()
    let qa = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
    let receipt = try await tool.delete(scanID: scan.id, ids: [qa.id])
    XCTAssertEqual(receipt.results.count, 1)
    XCTAssertEqual(receipt.results.first?.status, .deleted)
    XCTAssertEqual(receipt.availableSpaceChange, -20, "Concurrent writers can make the measured space change negative")
    let deletes = await fixture.deletionCalls
    XCTAssertEqual(deletes, [["simctl", "delete", SimulatorFixture.qa]])
    let remaining = await fixture.deviceIdentifiers
    XCTAssertTrue(remaining.contains(SimulatorFixture.active))
    do { _ = try await tool.delete(scanID: scan.id, ids: [qa.id]); XCTFail("A confirmation is single use") } catch {}
    let afterRepeat = await fixture.deletionCalls
    XCTAssertEqual(afterRepeat, deletes)
  }

  func testPartialFailuresDoNotHideSuccessfulItems() async throws {
    let fixture = SimulatorFixture()
    await fixture.failDeletion(SimulatorFixture.qa)
    let tool = client(fixture)
    let scan = try await tool.scan()
    let devices = scan.items.filter { $0.kind == .device }
    let receipt = try await tool.delete(scanID: scan.id, ids: Set(devices.map(\.id)))
    XCTAssertEqual(receipt.results.count, 2)
    XCTAssertEqual(receipt.results.first { $0.item.identifier == SimulatorFixture.qa }?.status, .failed)
    XCTAssertEqual(receipt.results.first { $0.item.identifier == SimulatorFixture.active }?.status, .deleted)
    XCTAssertTrue(receipt.results.allSatisfy { !$0.message.isEmpty })
  }

  func testRuntimeSuccessRequiresObservedRemovalAndStillPresentRuntimeIsPending() async throws {
    for observations in [0, 2, 100] {
      let fixture = SimulatorFixture()
      await fixture.delayRuntimeRemoval(observations)
      let tool = client(fixture)
      let scan = try await tool.scan()
      let runtime = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.unusedRuntime })
      let receipt = try await tool.delete(scanID: scan.id, ids: [runtime.id], runtimeScopeAcknowledged: true)
      XCTAssertEqual(receipt.results.first?.status, observations == 100 ? .pending : .deleted,
                     "simctl may accept asynchronous removal before the runtime disappears")
      let deletes = await fixture.deletionCalls
      XCTAssertEqual(deletes, [["simctl", "runtime", "delete", SimulatorFixture.unusedRuntime]])
    }
  }

  func testRuntimeDeletionRequiresExplicitAcknowledgementOfOtherDeviceSets() async throws {
    let fixture = SimulatorFixture()
    let tool = client(fixture)
    let scan = try await tool.scan()
    let runtime = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.unusedRuntime })
    let device = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
    XCTAssertTrue(runtime.canDelete, "Zero dependencies in the default device set alone does not authorize global removal")
    do {
      _ = try await tool.delete(scanID: scan.id, ids: [runtime.id, device.id])
      XCTFail("Other device sets require a separate explicit acknowledgement before any mutation")
    } catch {}
    let beforeAcknowledgement = await fixture.deletionCalls
    XCTAssertTrue(beforeAcknowledgement.isEmpty, "Missing runtime acknowledgement must also prevent earlier device deletion")

    // No additional device sets are enumerated or represented as verified by this inventory.
    // The acknowledgement records the user's own review of that global runtime impact.
    let receipt = try await tool.delete(scanID: scan.id, ids: [runtime.id], runtimeScopeAcknowledged: true)
    XCTAssertEqual(receipt.results.first?.status, .deleted)
    let afterAcknowledgement = await fixture.deletionCalls
    XCTAssertEqual(afterAcknowledgement, [["simctl", "runtime", "delete", SimulatorFixture.unusedRuntime]])
    let remaining = await fixture.deviceIdentifiers
    XCTAssertTrue(remaining.contains(device.identifier))
  }

  func testAdviceUsesAnonymousIDsAndRejectsUnknownDuplicateProtectedOrExecutableRecommendations() async throws {
    let scan = try await client(SimulatorFixture()).scan()
    let messages = try SimulatorCleanupAdvice.messages(scan: scan, locale: "en")
    let payload = try XCTUnwrap(messages.last?["content"])
    let payloadDocument = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    XCTAssertEqual(payloadDocument["scope"] as? String, "defaultDeviceSetOnly")
    XCTAssertEqual(payloadDocument["otherDeviceSetsVerified"] as? Bool, false)
    for secret in ["Secret QA", "Personal active", "/private", "Secret folder", SimulatorFixture.qa,
                   SimulatorFixture.active, SimulatorFixture.unusedRuntime, "dataPath", "lastUsedAt"] {
      XCTAssertFalse(payload.contains(secret), "AI payload leaked: \(secret)")
    }
    let recommendedIndex = try XCTUnwrap(scan.items.prefix(20).firstIndex { $0.canDelete })
    let protectedIndex = try XCTUnwrap(scan.items.prefix(20).firstIndex { !$0.canDelete })
    let anonymous = "item\(recommendedIndex + 1)"
    let valid = "{\"summary\":\"Review this test environment first.\",\"recommendations\":[\"\(anonymous)\"]}"
    let advice = try SimulatorCleanupAdvice.parse(valid, scan: scan)
    XCTAssertEqual(advice.recommendedIDs, [scan.items[recommendedIndex].id])
    for invalid in [
      #"{"summary":"review","recommendations":["item999"]}"#,
      "{\"summary\":\"review\",\"recommendations\":[\"\(anonymous)\",\"\(anonymous)\"]}",
      "{\"summary\":\"review\",\"recommendations\":[\"item\(protectedIndex + 1)\"]}",
      #"{"summary":"review","recommendations":[],"command":"simctl delete all"}"#,
      #"{"summary":"review","recommendations":[],"path":"/private"}"#,
    ] { XCTAssertThrowsError(try SimulatorCleanupAdvice.parse(invalid, scan: scan)) }
  }

  func testAdviceUsesElapsedHoursAcrossCalendarDays() async throws {
    let scan = try await client(SimulatorFixture()).scan()
    let lastUse = try XCTUnwrap(scan.items.first?.lastUsedAt)
    let recent = SimulatorCleanupScan(createdAt: lastUse.addingTimeInterval(18 * 3_600), items: scan.items)
    let messages = try SimulatorCleanupAdvice.messages(scan: recent, locale: "en")
    let payload = try XCTUnwrap(messages.last?["content"])
    let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    let rows = try XCTUnwrap(document["items"] as? [[String: Any]])
    XCTAssertFalse(rows.isEmpty)
    XCTAssertTrue(rows.allSatisfy { ($0["lastUsedHoursAgo"] as? Int) == 18 })
    XCTAssertFalse(payload.contains("lastUsedDaysAgo"))
    XCTAssertFalse(payload.contains("lastUsedAt"))
  }

  @MainActor func testAIAdviceDoesNotSelectOrDeleteAndCanceledLateRepliesAreDiscarded() async throws {
    let fixture = SimulatorFixture()
    let reply = DelayedSimulatorCompletion()
    let store = SimulatorCleanupStore(client: client(fixture), completion: { _, _ in await reply.wait() })
    store.startScan()
    try await waitUntil { !store.isBusy }
    XCTAssertTrue(store.selection.isEmpty)
    store.analyze(apiKey: "fixture-only")
    try await waitUntil { await reply.started }
    store.cancelReadOnly()
    await reply.finish()
    try await Task.sleep(for: .milliseconds(20))
    XCTAssertNil(store.advice)
    XCTAssertTrue(store.selection.isEmpty)
    XCTAssertEqual(store.phase, .idle)
    let deletes = await fixture.deletionCalls
    XCTAssertTrue(deletes.isEmpty)

    let success = SimulatorCleanupStore(client: client(fixture), completion: { _, _ in
      #"{"summary":"Review the test environment before deleting.","recommendations":["item1"]}"#
    })
    success.startScan()
    try await waitUntil { !success.isBusy }
    success.analyze(apiKey: "fixture-only")
    try await waitUntil { !success.isBusy }
    XCTAssertNotNil(success.advice)
    XCTAssertTrue(success.selection.isEmpty)
    let afterAdvice = await fixture.deletionCalls
    XCTAssertTrue(afterAdvice.isEmpty)
  }

  @MainActor func testSectionFitsNarrowAndWideLayoutsInBothAppearancesWithoutDeleting() async throws {
    let fixture = SimulatorFixture()
    await fixture.changeDevice(SimulatorFixture.active) { $0.state = "Booted" }
    let store = SimulatorCleanupStore(client: client(fixture))
    store.startScan()
    try await waitUntil { !store.isBusy }
    for width in [440, 660] {
      for dark in [false, true] {
        let content = SimulatorCleanupSection(store: store).frame(width: CGFloat(width)).padding(20)
          .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width + 40, height: 1_500)
        host.layoutSubtreeIfNeeded()
        host.frame.size = host.fittingSize
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.frame.width, CGFloat(width + 40), accuracy: 1)
        XCTAssertLessThan(host.frame.height, 1_800)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CLEANUP_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("simulator-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
    let deletes = await fixture.deletionCalls
    XCTAssertTrue(deletes.isEmpty)
  }

  @MainActor func testConfirmationShowsSelectedDeviceAndRuntimeInNarrowAndWideAppearancesWithoutExecuting() async throws {
    let fixture = SimulatorFixture()
    let scan = try await client(fixture).scan()
    let device = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.qa })
    let runtime = try XCTUnwrap(scan.items.first { $0.identifier == SimulatorFixture.unusedRuntime })
    let confirmation = SimulatorCleanupConfirmation(scanID: scan.id, items: [device, runtime])
    var approvals = 0
    for width in [440, 660] {
      for dark in [false, true] {
        let content = SimulatorCleanupConfirmationView(confirmation: confirmation) { _ in approvals += 1 }
          .frame(width: CGFloat(width), height: 760)
          .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 760)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
        XCTAssertLessThanOrEqual(host.fittingSize.height, 760)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CLEANUP_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("simulator-confirmation-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
    XCTAssertEqual(approvals, 0, "Showing a confirmation must never invoke its destructive action")
    let deletes = await fixture.deletionCalls
    XCTAssertTrue(deletes.isEmpty)
  }

  func testInstalledSimulatorInventoryWhenExplicitlyRequested() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_SIMULATOR_SCAN"] == "1" else {
      throw XCTSkip("Opt-in read-only simulator integration check")
    }
    let scan = try await SimulatorCleanupClient().scan()
    XCTAssertEqual(Set(scan.items.map(\.id)).count, scan.items.count)
    XCTAssertTrue(scan.items.filter { $0.kind == .device && $0.state != "Shutdown" }.allSatisfy { !$0.canDelete })
    print("Simulator inventory: \(scan.items.filter { $0.kind == .device }.count) devices, \(scan.items.filter { $0.kind == .runtime }.count) runtimes; incomplete=\(scan.incomplete)")
  }

  private func client(_ fixture: SimulatorFixture, clock: SimulatorFixtureClock = SimulatorFixtureClock()) -> SimulatorCleanupClient {
    SimulatorCleanupClient(run: { executable, arguments in try await fixture.run(executable, arguments) },
      clock: { clock.now() }, capacity: { await fixture.capacity() }, pause: {})
  }

  @MainActor private func waitUntil(_ predicate: @escaping () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !(await predicate()), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    let settled = await predicate()
    XCTAssertTrue(settled, "Asynchronous simulator state did not settle")
  }
}

private final class SimulatorFixtureClock: @unchecked Sendable {
  private let lock = NSLock()
  private var date = Date(timeIntervalSince1970: 1_793_059_200)
  func now() -> Date { lock.lock(); defer { lock.unlock() }; return date }
  func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; date.addTimeInterval(seconds) }
}

private actor SimulatorFixture {
  static let qa = "11111111-1111-4111-8111-111111111111"
  static let active = "22222222-2222-4222-8222-222222222222"
  static let unusedRuntime = "33333333-3333-4333-8333-333333333333"
  static let sharedRuntime = "44444444-4444-4444-8444-444444444444"
  static let sharedIdentifier = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"
  static let unusedIdentifier = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"

  struct Device: Sendable {
    var identifier: String
    var name: String
    var runtime: String = SimulatorFixture.sharedIdentifier
    var state = "Shutdown"
    var available: Bool? = true
    var bytes: UInt64? = 1_500_000_000
  }
  struct Runtime: Sendable {
    var identifier: String
    var runtimeIdentifier: String
    var version: String
    var state = "Ready"
    var deletable: Bool? = true
  }
  struct Call: Sendable { let executable: String; let arguments: [String] }
  private(set) var calls: [Call] = []
  private var devices: [Device] = [
    .init(identifier: SimulatorFixture.qa, name: "Secret QA / very-long-test-environment-name-for-layout"),
    .init(identifier: SimulatorFixture.active, name: "Personal active environment", bytes: 7_000_000_000),
  ]
  private var runtimes: [Runtime] = [
    .init(identifier: SimulatorFixture.unusedRuntime, runtimeIdentifier: SimulatorFixture.unusedIdentifier, version: "27.0"),
    .init(identifier: SimulatorFixture.sharedRuntime, runtimeIdentifier: SimulatorFixture.sharedIdentifier, version: "27.1"),
  ]
  private var devicesOverride: String?
  private var runtimesOverride: String?
  private var deviceTypesOverride: String?
  private var deviceTypesStatus: Int32 = 0
  private var deviceTypesCancellation = false
  private var failing: Set<String> = []
  private var bootAfterDeletion: String?
  private var runtimeRemovalDelay = 0
  private var runtimeReadHook: (remaining: Int, action: @Sendable () -> Void)?
  private var pendingRuntime: (identifier: String, remaining: Int)?
  private var readings: [Int64] = [1_000, 980]
  var deletionCalls: [[String]] { calls.map(\.arguments).filter { $0.contains("delete") } }
  var deviceIdentifiers: Set<String> { Set(devices.map(\.identifier)) }
  func capacity() -> Int64? { readings.isEmpty ? nil : readings.removeFirst() }
  func overrideDevices(_ value: String) { devicesOverride = value }
  func overrideRuntimes(_ value: String) { runtimesOverride = value }
  func overrideDeviceTypes(_ value: String, status: Int32 = 0) {
    deviceTypesOverride = value
    deviceTypesStatus = status
  }
  func cancelDeviceTypesRead() { deviceTypesCancellation = true }
  func failDeletion(_ identifier: String) { failing.insert(identifier) }
  func bootDeviceAfterFirstDeletion(_ identifier: String) { bootAfterDeletion = identifier }
  func delayRuntimeRemoval(_ observations: Int) { runtimeRemovalDelay = observations }
  func afterRuntimeRead(_ count: Int, action: @escaping @Sendable () -> Void) {
    runtimeReadHook = (remaining: count, action: action)
  }
  func changeDevice(_ identifier: String, _ mutation: @Sendable (inout Device) -> Void) {
    if let index = devices.firstIndex(where: { $0.identifier == identifier }) { mutation(&devices[index]) }
  }
  func changeRuntime(_ identifier: String, _ mutation: @Sendable (inout Runtime) -> Void) {
    if let index = runtimes.firstIndex(where: { $0.identifier == identifier }) { mutation(&runtimes[index]) }
  }

  func run(_ executable: URL, _ arguments: [String]) throws -> CleanupCommandResult {
    calls.append(Call(executable: executable.path, arguments: arguments))
    if arguments == ["simctl", "list", "devicetypes", "--json"] {
      if deviceTypesCancellation { throw CancellationError() }
      let output = try deviceTypesOverride ?? json(["devicetypes": [
        ["identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo", "modelIdentifier": "iPhone19,4"],
        ["identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17", "modelIdentifier": "iPhone18,3"],
      ]])
      return .init(status: deviceTypesStatus, output: output)
    }
    if arguments == ["simctl", "list", "devices", "--json"] {
      if let devicesOverride { return .init(status: 0, output: devicesOverride) }
      var groups: [String: [[String: Any]]] = [:]
      for device in devices {
        var record: [String: Any] = ["udid": device.identifier, "name": device.name, "state": device.state,
          "dataPath": "/private/Secret folder/" + device.identifier + "/data", "lastUsedAt": "2026-10-18T12:00:00Z"]
        record["isAvailable"] = device.available
        record["dataPathSize"] = device.bytes
        record["deviceTypeIdentifier"] = device.identifier == Self.active
          ? "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo" : "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
        groups[device.runtime, default: []].append(record)
      }
      return .init(status: 0, output: try json(["devices": groups]))
    }
    if arguments == ["simctl", "runtime", "list", "--json"] {
      if let runtimesOverride { return .init(status: 0, output: runtimesOverride) }
      if let hook = runtimeReadHook {
        if hook.remaining == 1 { runtimeReadHook = nil; hook.action() }
        else { runtimeReadHook = (remaining: hook.remaining - 1, action: hook.action) }
      }
      if let pending = pendingRuntime {
        if pending.remaining == 0 {
          runtimes.removeAll { $0.identifier == pending.identifier }; pendingRuntime = nil
        } else { pendingRuntime = (pending.identifier, pending.remaining - 1) }
      }
      var records: [String: [String: Any]] = [:]
      for runtime in runtimes {
        var record: [String: Any] = ["identifier": runtime.identifier, "runtimeIdentifier": runtime.runtimeIdentifier,
          "version": runtime.version, "build": "24A434", "state": runtime.state, "sizeBytes": UInt64(8_000_000_000),
          "lastUsedAt": "2026-10-18T12:00:00Z", "platformIdentifier": "com.apple.platform.iphonesimulator"]
        record["deletable"] = runtime.deletable
        records[runtime.identifier] = record
      }
      return .init(status: 0, output: try json(records))
    }
    if arguments.count == 3, arguments[0...1] == ["simctl", "delete"] {
      let identifier = arguments[2]
      if failing.contains(identifier) { return .init(status: 1, output: "", diagnostics: "fixture deletion failed") }
      devices.removeAll { $0.identifier == identifier }
      if let next = bootAfterDeletion, let index = devices.firstIndex(where: { $0.identifier == next }) {
        devices[index].state = "Booted"
        bootAfterDeletion = nil
      }
      return .init(status: 0, output: "")
    }
    if arguments.count == 4, arguments[0...2] == ["simctl", "runtime", "delete"] {
      let identifier = arguments[3]
      if failing.contains(identifier) { return .init(status: 1, output: "", diagnostics: "fixture deletion failed") }
      pendingRuntime = (identifier, runtimeRemovalDelay)
      return .init(status: 0, output: "")
    }
    throw CocoaError(.featureUnsupported)
  }

  private func json(_ object: Any) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: object, options: .sortedKeys), as: UTF8.self)
  }
}

private actor DelayedSimulatorCompletion {
  private(set) var started = false
  private var continuation: CheckedContinuation<String, Never>?
  func wait() async -> String {
    started = true
    return await withCheckedContinuation { continuation = $0 }
  }
  func finish() {
    continuation?.resume(returning: #"{"summary":"Review the environment.","recommendations":[]}"#)
    continuation = nil
  }
}
