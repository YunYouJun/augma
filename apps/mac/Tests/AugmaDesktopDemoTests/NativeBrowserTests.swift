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
    main.attach(page, tabID: store.activeTab.id, presentation: .main)
    XCTAssertTrue(page.superview === main)
    store.setPresentation(.immersive)
    immersive.attach(page, tabID: store.activeTab.id, presentation: .immersive)
    XCTAssertTrue(page.superview === immersive)
    XCTAssertTrue(main.subviews.isEmpty)
    main.attach(page, tabID: store.activeTab.id, presentation: .main)
    XCTAssertTrue(page.superview === immersive)
    main.detach()
    XCTAssertTrue(page.superview === immersive)
    store.setPresentation(.main)
    main.attach(page, tabID: store.activeTab.id, presentation: .main)
    immersive.attach(page, tabID: store.activeTab.id, presentation: .immersive)
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
    old.attach(page, tabID: store.activeTab.id, presentation: .main)
    old.detach()
    let reopened = NativeBrowserWebHost(store: store)
    reopened.attach(page, tabID: store.activeTab.id, presentation: .main)
    old.attach(page, tabID: store.activeTab.id, presentation: .main)
    XCTAssertTrue(page.superview === reopened)
    old.detach()
    XCTAssertTrue(page.superview === reopened)
    reopened.detach()
  }

  func testInactiveTabHostCannotReclaimTheBrowserSurface() {
    let store = NativeBrowserStore()
    let first = store.activeTab
    let host = NativeBrowserWebHost(store: store)
    let page = WKWebView(frame: .zero)
    host.attach(page, tabID: first.id, presentation: .main)
    XCTAssertTrue(page.superview === host)

    store.newTab()
    host.attach(page, tabID: first.id, presentation: .main)

    XCTAssertNil(page.superview, "A delayed update from an inactive tab must not cover the active tab")
  }

  func testPageIsCreatedOnlyOnceAndDoesNotInheritApplicationScripts() throws {
    var created: [RecordingBrowserWebView] = []
    var externalURLs: [URL] = []
    let store = NativeBrowserStore(openExternal: { url, _ in externalURLs.append(url); return true }, createWebView: { configuration in
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

  func testExternalBrowserShortcutRoutesTheActivePageToTheSelectedBrowser() throws {
    var openings: [(url: URL, target: NativeBrowserExternalTarget)] = []
    let store = NativeBrowserStore(openExternal: { url, target in
      openings.append((url, target))
      return true
    }, createWebView: { configuration in
      RecordingBrowserWebView(frame: .zero, configuration: configuration)
    })
    defer { store.shutdown() }
    let url = try XCTUnwrap(URL(string: "https://example.com/current"))
    store.navigate(to: url)

    store.openExternally(in: .safari)
    store.openExternally(in: .chrome)

    XCTAssertEqual(openings.map(\.url), [url, url])
    XCTAssertEqual(openings.map(\.target), [.safari, .chrome])
  }

  func testExternalBrowserShortcutReportsWhenTheSelectedBrowserCannotOpenThePage() throws {
    let store = NativeBrowserStore(openExternal: { _, _ in false }, createWebView: { configuration in
      RecordingBrowserWebView(frame: .zero, configuration: configuration)
    })
    defer { store.shutdown() }
    store.navigate(to: try XCTUnwrap(URL(string: "https://example.com/current")))

    store.openExternally(in: .chrome)

    let error = try XCTUnwrap(store.error)
    XCTAssertTrue(error.contains("Google Chrome"))
  }

  func testNewTabsKeepIndependentPagesAndSwitchActiveState() throws {
    var created: [RecordingBrowserWebView] = []
    let store = NativeBrowserStore(createWebView: { configuration in
      let view = RecordingBrowserWebView(frame: .zero, configuration: configuration)
      created.append(view)
      return view
    })
    defer { store.shutdown() }
    let firstURL = try XCTUnwrap(URL(string: "https://example.com/first"))
    let secondURL = try XCTUnwrap(URL(string: "https://example.com/second"))

    store.navigate(to: firstURL)
    let firstTab = store.activeTab
    XCTAssertEqual(store.tabs.count, 1)
    XCTAssertTrue(store.webView === firstTab.webView)

    let secondTab = store.newTab()
    XCTAssertEqual(store.tabs.count, 2)
    XCTAssertEqual(store.activeTabID, secondTab.id)
    XCTAssertFalse(store.hasPage)
    store.navigate(to: secondURL)

    XCTAssertEqual(created.count, 2)
    XCTAssertEqual(created[0].requests.compactMap(\.url), [firstURL])
    XCTAssertEqual(created[1].requests.compactMap(\.url), [secondURL])

    store.selectTab(firstTab.id)
    XCTAssertEqual(store.currentURL, firstURL)
    XCTAssertEqual(store.addressInput, firstURL.absoluteString)
    store.selectTab(secondTab.id)
    XCTAssertEqual(store.currentURL, secondURL)

    store.selectTab(firstTab.id)
    store.selectTab(secondTab.id)
    XCTAssertEqual(created[0].requests.count, 1, "Switching tabs must not reload a background page")
    XCTAssertEqual(created[1].requests.count, 1, "Switching tabs must not reload the active page")
  }

  func testNewWindowRequestsOpenInANewTab() throws {
    var created: [RecordingBrowserWebView] = []
    let store = NativeBrowserStore(createWebView: { configuration in
      let view = RecordingBrowserWebView(frame: .zero, configuration: configuration)
      created.append(view)
      return view
    })
    defer { store.shutdown() }
    let url = try XCTUnwrap(URL(string: "https://example.com/popup"))

    let tab = try XCTUnwrap(store.openTab(with: URLRequest(url: url)))

    XCTAssertEqual(store.tabs.count, 2)
    XCTAssertEqual(store.activeTabID, tab.id)
    XCTAssertEqual(store.currentURL, url)
    XCTAssertEqual(created.count, 1)
    XCTAssertEqual(created[0].requests.compactMap(\.url), [url])
  }

  func testClosingTabsSelectsNeighborsAndNeverLeavesAnEmptyStore() {
    let store = NativeBrowserStore()
    defer { store.shutdown() }
    let first = store.tabs[0]
    let second = store.newTab()
    let third = store.newTab()

    store.selectTab(second.id)
    store.closeTab(second.id)
    XCTAssertEqual(store.activeTabID, third.id)
    XCTAssertEqual(store.tabs.map(\.id), [first.id, third.id])

    store.closeTab(third.id)
    XCTAssertEqual(store.activeTabID, first.id)

    store.closeTab(first.id)
    XCTAssertEqual(store.tabs.count, 1)
    XCTAssertEqual(store.activeTabID, first.id)
    XCTAssertFalse(store.hasPage)
    XCTAssertTrue(store.addressInput.isEmpty)
  }

  func testTabCyclingAndAddressEntryUseTheActiveTab() throws {
    var created: [RecordingBrowserWebView] = []
    let store = NativeBrowserStore(createWebView: { configuration in
      let view = RecordingBrowserWebView(frame: .zero, configuration: configuration)
      created.append(view)
      return view
    })
    defer { store.shutdown() }
    let first = store.tabs[0]
    let second = store.newTab()

    store.addressInput = "example.com/active"
    store.submitAddress()
    XCTAssertEqual(created.count, 1)
    XCTAssertEqual(created[0].requests.compactMap(\.url), [try XCTUnwrap(URL(string: "https://example.com/active"))])

    store.selectPreviousTab()
    XCTAssertEqual(store.activeTabID, first.id)
    store.selectNextTab()
    XCTAssertEqual(store.activeTabID, second.id)
  }

  func testHidingAndRecreatingImmersiveHostKeepsPageAndDoesNotReload() throws {
    let page = RecordingBrowserWebView(frame: .zero)
    let store = NativeBrowserStore(createWebView: { _ in page })
    defer { store.shutdown() }
    let url = try XCTUnwrap(URL(string: "https://example.com/workspace"))
    store.navigate(to: url)
    store.setPresentation(.immersive)
    let hidden = NativeBrowserWebHost(store: store)
    hidden.attach(page, tabID: store.activeTab.id, presentation: .immersive)
    store.suspendPlayback()
    hidden.detach()
    XCTAssertTrue(store.hasPage)
    XCTAssertEqual(store.currentURL, url)
    let resumed = NativeBrowserWebHost(store: store)
    resumed.attach(page, tabID: store.activeTab.id, presentation: .immersive)
    hidden.attach(page, tabID: store.activeTab.id, presentation: .immersive)
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
