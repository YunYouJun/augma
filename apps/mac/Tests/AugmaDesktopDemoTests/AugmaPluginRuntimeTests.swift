import AppKit
import WebKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class AugmaPluginRuntimeTests: XCTestCase {
  func testBuiltInPluginFollowsAppLanguageWithoutRestartingItsSession() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let package = try AugmaPluginPackageReader.inspect(root.appending(path: "plugins/breathing-orbit/BreathingOrbit.augmaplugin"))
    let runtime = AugmaPluginRuntime(package: package, language: "en-US")
    let view = runtime.start()
    defer { runtime.shutdown() }
    try await waitFor(view, "document.documentElement.lang === 'en-US' && document.getElementById('toggle').textContent === 'Begin'")
    _ = try await view.evaluateJavaScript("window.sessionMarker = 'preserved'; document.getElementById('toggle').click()")
    runtime.setLanguage("zh-CN")
    try await waitFor(view, "document.documentElement.lang === 'zh-CN' && document.getElementById('toggle').textContent === '暂停'")
    let marker = try await view.evaluateJavaScript("window.sessionMarker") as? String
    let label = try await view.evaluateJavaScript("document.getElementById('orbit').getAttribute('aria-label')") as? String
    XCTAssertEqual(marker, "preserved")
    XCTAssertEqual(label, "呼吸节奏圆环")
    runtime.setLanguage("en-US")
    try await waitFor(view, "document.getElementById('orbit').getAttribute('aria-label') === 'Breathing rhythm orbit'")
    XCTAssertEqual(view.configuration.userContentController.userScripts.count, 2)
    view.reload()
    try await waitFor(view, "document.documentElement.lang === 'en-US' && typeof navigator.geolocation === 'undefined'")
  }

  func testLocalJavaScriptRunsButCSPRejectsNetworkAndShutdownDestroysTheDocument() async throws {
    let fixture = try AugmaPluginFixture(script: """
      window.fixtureLoaded = true;
      window.intervalTicks = 0;
      setInterval(() => window.intervalTicks++, 10);
      document.addEventListener('securitypolicyviolation', event => { window.blockedDirective = event.effectiveDirective; });
      fetch('https://example.com/augma-plugin-test').catch(() => { window.fetchRejected = true; });
      """)
    defer { fixture.remove() }
    let package = try AugmaPluginPackageReader.inspect(fixture.source)
    let runtime = AugmaPluginRuntime(package: package)
    let view = runtime.start()
    defer { runtime.shutdown() }
    XCTAssertFalse(view.configuration.websiteDataStore.isPersistent)
    XCTAssertTrue(view.configuration.userContentController.userScripts.count > 0)
    try await waitFor(view, "window.fixtureLoaded === true && window.fetchRejected === true && window.intervalTicks > 0")
    let directive = try await view.evaluateJavaScript("window.blockedDirective") as? String
    XCTAssertEqual(directive, "connect-src")
    let compatibility = try await view.evaluateJavaScript("document.compatMode") as? String
    XCTAssertEqual(compatibility, "CSS1Compat")
    let geolocation = try await view.evaluateJavaScript("typeof navigator.geolocation") as? String
    XCTAssertEqual(geolocation, "undefined")
    runtime.shutdown()
    XCTAssertFalse(runtime.running)
    XCTAssertNil(runtime.webView)
    try await waitFor(view, "typeof window.fixtureLoaded === 'undefined'")
  }

  private func waitFor(_ view: WKWebView, _ expression: String) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(8))
    while ContinuousClock.now < deadline {
      if let result = try? await view.evaluateJavaScript(expression) as? Bool, result { return }
      try await Task.sleep(for: .milliseconds(30))
    }
    XCTFail("WebKit did not satisfy: \(expression)")
    throw URLError(.timedOut)
  }
}
