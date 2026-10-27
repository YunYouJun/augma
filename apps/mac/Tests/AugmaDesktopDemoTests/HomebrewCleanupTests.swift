import AppKit
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

private let brewPreviewOutput = """
Would remove: /private/fixture/Homebrew/old.tar.gz (12MB)
Would remove (broken link): /private/fixture/Homebrew/link
==> This operation would free approximately 12MB of disk space.
"""

final class HomebrewCleanupTests: XCTestCase {
  func testPreviewUsesDecimalUnitsPreservesWarningsAndDoesNotExportPathsToAI() throws {
    let preview = HomebrewCleanupClient.parse(version: "Homebrew 7.0.11",
      result: .init(status: 0, output: brewPreviewOutput, diagnostics: "Warning: Skipping fixture"))
    XCTAssertTrue(preview.canExecute)
    XCTAssertEqual(preview.itemCount, 2)
    XCTAssertEqual(preview.estimatedBytes, 12_000_000)
    XCTAssertTrue(preview.report.contains("Warning:"))
    let messages = try CleanupAdvice.messages(scan: CleanupScan(candidates: []), snapshot: SystemSnapshot(),
                                               locale: "en", homebrew: preview)
    let payload = try XCTUnwrap(messages.last?["content"])
    XCTAssertTrue(payload.contains("12000000"))
    for secret in ["private", "fixture", "old.tar.gz", "Skipping"] { XCTAssertFalse(payload.contains(secret)) }
  }

  func testUnknownVersionsFormatsAutoremoveAndEnvironmentOverridesArePreviewOnly() {
    for (version, output, controlled) in [
      ("Homebrew 8.0.0", brewPreviewOutput, true),
      ("Homebrew 7.0.11", brewPreviewOutput + "\nWould autoremove 1 formula: fixture", true),
      ("Homebrew 7.0.11", brewPreviewOutput + "\nUnexpected new output", true),
      ("Homebrew 7.0.11", brewPreviewOutput, false),
    ] {
      let preview = HomebrewCleanupClient.parse(version: version, result: .init(status: 0, output: output),
                                                controlledEnvironment: controlled)
      XCTAssertFalse(preview.canExecute)
      XCTAssertNotNil(preview.executionRestriction)
    }
    XCTAssertFalse(HomebrewCleanupClient.parse(version: "Homebrew 7.0.11", result: .init(status: 0, output: "")).canExecute)
  }

  func testChangedPreviewAndStaleIDsCannotReachCleanup() async throws {
    let commands = BrewFixture()
    let client = client(commands)
    let old = try await client.preview()
    let current = try await client.preview()
    do { _ = try await client.cleanup(previewID: old.id); XCTFail("Old IDs must be rejected") } catch {}
    await commands.changeOutput(brewPreviewOutput.replacingOccurrences(of: "12MB", with: "13MB"))
    do { _ = try await client.cleanup(previewID: current.id); XCTFail("Changed scope must be reviewed") } catch {}
    let calls = await commands.arguments
    XCTAssertFalse(calls.contains(["cleanup"]))
  }

  func testExecutionRechecksThenUsesOnlyTheFixedCommandAndMeasuresSpace() async throws {
    let commands = BrewFixture()
    let client = client(commands)
    let preview = try await client.preview()
    let receipt = try await client.cleanup(previewID: preview.id)
    XCTAssertTrue(receipt.succeeded)
    XCTAssertEqual(receipt.availableSpaceChange, -20, "Other writers can reduce free space during cleanup")
    let calls = await commands.arguments
    XCTAssertEqual(calls, [["--version"], ["cleanup", "--dry-run"], ["--version"], ["cleanup", "--dry-run"], ["cleanup"]])
    do { _ = try await client.cleanup(previewID: preview.id); XCTFail("A plan is single use") } catch {}
  }

  func testNonzeroPreviewDoesNotEnableExecutionAndPartialCleanupRemainsAReceipt() async throws {
    let commands = BrewFixture()
    let client = client(commands)
    await commands.setStatus(1)
    do { _ = try await client.preview(); XCTFail("Failed previews cannot become executable") } catch {}
    await commands.setStatus(0)
    let preview = try await client.preview()
    await commands.setCleanupStatus(1)
    let receipt = try await client.cleanup(previewID: preview.id)
    XCTAssertFalse(receipt.succeeded)
    XCTAssertTrue(receipt.report.contains("partial cleanup"))
  }

  func testMissingHomebrewDoesNotInstallAnything() async {
    let client = HomebrewCleanupClient(executable: nil)
    do { _ = try await client.preview(); XCTFail("Missing Homebrew must be reported") } catch {}
  }

  func testEnvironmentDisablesAutoremoveUpdatesAnalyticsAndSudo() {
    let environment = HomebrewCleanupClient.environment()
    for key in ["HOMEBREW_NO_AUTOREMOVE", "HOMEBREW_NO_AUTO_UPDATE", "HOMEBREW_NO_ANALYTICS", "HOMEBREW_NO_SUDO"] {
      XCTAssertEqual(environment[key], "1")
    }
    XCTAssertEqual(environment["LC_ALL"], "C")
    XCTAssertNil(environment["RUBYOPT"])
    XCTAssertNil(environment["HOMEBREW_GITHUB_API_TOKEN"])
  }

  @MainActor func testProcessCapturesBothStreamsAndEnforcesTimeoutOutputLimitAndCancellation() async throws {
    let result = try await CleanupCommandProcess().run(executable: URL(filePath: "/bin/sh"),
      arguments: ["-c", "printf preview; printf warning >&2; exit 3"], environment: [:])
    XCTAssertEqual(result.status, 3)
    XCTAssertEqual(result.output, "preview")
    XCTAssertEqual(result.diagnostics, "warning")
    do {
      _ = try await CleanupCommandProcess(timeout: .milliseconds(40)).run(executable: URL(filePath: "/bin/sleep"),
        arguments: ["5"], environment: [:])
      XCTFail("Slow commands must time out")
    } catch CleanupCommandProcess.Failure.timedOut {} catch { XCTFail("Unexpected error: \(error)") }
    do {
      _ = try await CleanupCommandProcess(maximumOutput: 64).run(executable: URL(filePath: "/usr/bin/yes"),
        arguments: ["preview"], environment: [:])
      XCTFail("Output must be bounded")
    } catch CleanupCommandProcess.Failure.outputLimit {} catch { XCTFail("Unexpected error: \(error)") }
    let task = Task {
      try await CleanupCommandProcess().run(executable: URL(filePath: "/bin/sleep"), arguments: ["5"], environment: [:])
    }
    try await Task.sleep(for: .milliseconds(30))
    task.cancel()
    do { _ = try await task.value; XCTFail("Cancellation must stop the command") } catch is CancellationError {}
  }

  @MainActor func testPreviewNeverAutomaticallyCleansAndPanelFitsBothAppearances() async throws {
    let commands = BrewFixture()
    let store = HomebrewCleanupStore(client: client(commands))
    store.startPreview()
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while store.isBusy, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    XCTAssertEqual(store.preview?.itemCount, 2)
    let calls = await commands.arguments
    XCTAssertFalse(calls.contains(["cleanup"]))
    for width in [440, 660] {
      for dark in [false, true] {
        let content = HomebrewCleanupSection(store: store).frame(width: CGFloat(width)).padding(20)
          .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width + 40, height: 600)
        host.layoutSubtreeIfNeeded()
        host.frame.size = host.fittingSize
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.frame.width, CGFloat(width + 40), accuracy: 1)
        XCTAssertLessThan(host.frame.height, 500)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CLEANUP_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("homebrew-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
  }

  func testInstalledHomebrewPreviewWhenExplicitlyRequested() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_INSTALLED_HOMEBREW"] == "1" else {
      throw XCTSkip("Opt-in read-only integration check")
    }
    let preview = try await HomebrewCleanupClient().preview()
    print("Homebrew preview: \(preview.version), \(preview.itemCount) items, estimate=\(preview.estimatedBytes ?? 0), executable=\(preview.canExecute)")
    XCTAssertFalse(preview.report.contains("Would autoremove"))
  }

  private func client(_ fixture: BrewFixture) -> HomebrewCleanupClient {
    HomebrewCleanupClient(executable: URL(filePath: "/fixture/brew"),
      run: { _, arguments in await fixture.run(arguments) }, controlledEnvironment: { true }, capacity: { await fixture.capacity() })
  }
}

private actor BrewFixture {
  var arguments: [[String]] = []
  private var output = brewPreviewOutput
  private var status: Int32 = 0
  private var cleanupStatus: Int32 = 0
  private var readings: [Int64] = [100, 80]
  func changeOutput(_ value: String) { output = value }
  func setStatus(_ value: Int32) { status = value }
  func setCleanupStatus(_ value: Int32) { cleanupStatus = value }
  func capacity() -> Int64? { readings.isEmpty ? nil : readings.removeFirst() }
  func run(_ args: [String]) -> CleanupCommandResult {
    arguments.append(args)
    if args == ["--version"] { return .init(status: 0, output: "Homebrew 7.0.11\n") }
    if args == ["cleanup"] { return .init(status: cleanupStatus, output: "partial cleanup") }
    return .init(status: status, output: output)
  }
}
