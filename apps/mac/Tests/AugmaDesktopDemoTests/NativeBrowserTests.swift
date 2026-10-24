import AppKit
import WebKit
import XCTest
@testable import AugmaDesktopDemo

final class NativeBrowserAddressTests: XCTestCase {
  func testHTTPAddressesAndBareDomains() throws {
    XCTAssertEqual(try NativeBrowserAddress.resolve(" example.com/path?q=1 ").absoluteString, "https://example.com/path?q=1")
    XCTAssertEqual(try NativeBrowserAddress.resolve("http://localhost:8080/test").absoluteString, "http://localhost:8080/test")
    XCTAssertEqual(try NativeBrowserAddress.resolve("localhost:8080/test").absoluteString, "https://localhost:8080/test")
    XCTAssertEqual(try NativeBrowserAddress.resolve("example.com:8080?q=1").absoluteString, "https://example.com:8080?q=1")
    XCTAssertEqual(try NativeBrowserAddress.resolve("//example.com/page").absoluteString, "https://example.com/page")
    XCTAssertEqual(try NativeBrowserAddress.resolve("https://例子.测试/你好").host, "xn--fsqu00a.xn--0zwm56d")
  }

  func testSearchEscapesContentAsOneQueryValue() throws {
    let url = try NativeBrowserAddress.resolve("苹果 地图 & 页面 #1")
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.host, "www.bing.com")
    XCTAssertEqual(components.queryItems, [URLQueryItem(name: "q", value: "苹果 地图 & 页面 #1")])
    XCTAssertNil(components.fragment)
  }

  func testAddressEntryRejectsExecutableAndLocalSchemes() {
    for text in ["javascript:alert(1)", "data:text/html,hello", "file:///etc/hosts", "augma-demo://index.html", "mailto:test@example.com", "about:blank"] {
      XCTAssertThrowsError(try NativeBrowserAddress.resolve(text), text) { error in
        XCTAssertEqual(error as? NativeBrowserAddressError, .unsupportedScheme)
      }
    }
  }

  func testMalformedCredentialsPortsAndControlsAreRejected() {
    for text in ["https://", "https://bad host.test/", "https://user:password@example.com", "http://localhost:70000", "hello\nworld", "https://example.com/\u{0}"] {
      XCTAssertThrowsError(try NativeBrowserAddress.resolve(text), text)
    }
    XCTAssertThrowsError(try NativeBrowserAddress.resolve("   "))
    XCTAssertThrowsError(try NativeBrowserAddress.resolve(String(repeating: "a", count: 8_193)))
  }
}

@MainActor
final class NativeBrowserSessionTests: XCTestCase {
  func testOpeningNativeBrowserLandingDoesNotCreateWebKitOrLoadPage() {
    let store = NativeBrowserStore()
    XCTAssertNil(store.webView)
    XCTAssertNil(store.currentURL)
    XCTAssertFalse(store.hasPage)
    store.addressInput = "javascript:alert(1)"
    store.submitAddress()
    XCTAssertNil(store.webView)
    XCTAssertNotNil(store.error)
    store.closePage()
    XCTAssertNil(store.error)
    XCTAssertTrue(store.addressInput.isEmpty)
  }

  func testHostsTransferTheSamePageAndLateDismantleDoesNotRemoveNewOwner() {
    let store = NativeBrowserStore()
    let page = WKWebView(frame: .zero)
    let main = NativeBrowserWebHost(store: store)
    let immersive = NativeBrowserWebHost(store: store)
    main.attach(page, presentation: .main)
    XCTAssertTrue(page.superview === main)
    store.setPresentation(.immersive)
    immersive.attach(page, presentation: .immersive)
    XCTAssertTrue(page.superview === immersive)
    XCTAssertTrue(main.subviews.isEmpty)
    main.attach(page, presentation: .main)
    XCTAssertTrue(page.superview === immersive)
    main.detach()
    XCTAssertTrue(page.superview === immersive)
    store.setPresentation(.main)
    main.attach(page, presentation: .main)
    immersive.attach(page, presentation: .immersive)
    XCTAssertTrue(page.superview === main)
    immersive.detach()
    XCTAssertTrue(page.superview === main)
    main.detach()
    XCTAssertNil(page.superview)
  }

  func testReopeningBrowserRejectsStaleUpdatesFromEarlierHostInSamePresentation() {
    let store = NativeBrowserStore()
    let page = WKWebView(frame: .zero)
    let old = NativeBrowserWebHost(store: store)
    old.attach(page, presentation: .main)
    old.detach()
    let reopened = NativeBrowserWebHost(store: store)
    reopened.attach(page, presentation: .main)
    old.attach(page, presentation: .main)
    XCTAssertTrue(page.superview === reopened)
    old.detach()
    XCTAssertTrue(page.superview === reopened)
    reopened.detach()
  }

  func testPageIsCreatedOnlyOnceAndDoesNotInheritApplicationScripts() throws {
    var created: [RecordingBrowserWebView] = []
    var externalURLs: [URL] = []
    let store = NativeBrowserStore(openExternal: { externalURLs.append($0); return true }, createWebView: { configuration in
      let view = RecordingBrowserWebView(frame: .zero, configuration: configuration)
      created.append(view)
      return view
    })
    XCTAssertTrue(created.isEmpty)
    let firstURL = try XCTUnwrap(URL(string: "https://example.com/first"))
    let secondURL = try XCTUnwrap(URL(string: "https://example.com/second"))
    store.navigate(to: firstURL)
    store.navigate(to: secondURL)
    XCTAssertEqual(created.count, 1)
    let view = try XCTUnwrap(created.first)
    XCTAssertEqual(view.requests.compactMap(\.url), [firstURL, secondURL])
    XCTAssertTrue(store.webView === view)
    XCTAssertTrue(view.configuration.userContentController.userScripts.isEmpty)
    XCTAssertNil(view.configuration.urlSchemeHandler(forURLScheme: "augma-demo"))
    XCTAssertFalse(view.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
    XCTAssertEqual(view.configuration.mediaTypesRequiringUserActionForPlayback, .all)
    XCTAssertTrue(externalURLs.isEmpty)
    store.openInDefaultBrowser()
    XCTAssertEqual(externalURLs, [secondURL])
    store.closePage()
    XCTAssertNil(store.webView)
    XCTAssertFalse(store.hasPage)
    XCTAssertNil(view.navigationDelegate)
    XCTAssertNil(view.uiDelegate)
  }

  func testHidingAndRecreatingImmersiveHostKeepsPageAndDoesNotReload() throws {
    let page = RecordingBrowserWebView(frame: .zero)
    let store = NativeBrowserStore(createWebView: { _ in page })
    defer { store.shutdown() }
    let url = try XCTUnwrap(URL(string: "https://example.com/workspace"))
    store.navigate(to: url)
    store.setPresentation(.immersive)
    let hidden = NativeBrowserWebHost(store: store)
    hidden.attach(page, presentation: .immersive)
    store.suspendPlayback()
    hidden.detach()
    XCTAssertTrue(store.hasPage)
    XCTAssertEqual(store.currentURL, url)
    let resumed = NativeBrowserWebHost(store: store)
    resumed.attach(page, presentation: .immersive)
    hidden.attach(page, presentation: .immersive)
    hidden.detach()
    XCTAssertTrue(page.superview === resumed)
    XCTAssertEqual(page.requests.count, 1, "Reveal should reuse the existing page")
    XCTAssertEqual(store.addressInput, url.absoluteString)
  }
}

@MainActor
private final class RecordingBrowserWebView: WKWebView {
  var requests: [URLRequest] = []
  override func load(_ request: URLRequest) -> WKNavigation? {
    requests.append(request)
    return nil
  }
}
