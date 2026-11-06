import AppKit
import Combine
import WebKit

enum NativeBrowserPresentation {
  case main, immersive
}

/// Window-level tab collection shared by the main window and immersive presentation.
/// Each tab owns its own WebKit instance; this store only mounts the active tab.
@MainActor
final class NativeBrowserStore: NSObject, ObservableObject {
  @Published private(set) var tabs: [NativeBrowserTab]
  @Published private(set) var activeTabID: UUID
  @Published private(set) var addressFocusRequest = 0
  @Published private(set) var presentation: NativeBrowserPresentation = .main

  private let openExternal: (URL, NativeBrowserExternalTarget) -> Bool
  private let createWebView: (WKWebViewConfiguration) -> WKWebView
  private var nextHostSequence: UInt64 = 0
  private var activeHostSequence: UInt64 = 0

  init(openExternal: @escaping (URL, NativeBrowserExternalTarget) -> Bool = NativeBrowserExternalTarget.open,
       createWebView: @escaping (WKWebViewConfiguration) -> WKWebView = { WKWebView(frame: .zero, configuration: $0) }) {
    self.openExternal = openExternal
    self.createWebView = createWebView
    let tab = NativeBrowserTab(openExternal: openExternal, createWebView: createWebView)
    tabs = [tab]
    activeTabID = tab.id
    super.init()
    tab.owner = self
  }

  var activeTab: NativeBrowserTab {
    tabs.first { $0.id == activeTabID } ?? tabs[0]
  }

  var addressInput: String {
    get { activeTab.addressInput }
    set { activeTab.addressInput = newValue }
  }
  var currentURL: URL? { activeTab.currentURL }
  var title: String { activeTab.title }
  var hasPage: Bool { activeTab.hasPage }
  var isLoading: Bool { activeTab.isLoading }
  var progress: Double { activeTab.progress }
  var canGoBack: Bool { activeTab.canGoBack }
  var canGoForward: Bool { activeTab.canGoForward }
  var error: String? { activeTab.error }
  var webView: WKWebView? { activeTab.webView }
  var canCloseTab: Bool { tabs.count > 1 || activeTab.hasPage }

  func submitAddress() { activeTab.submitAddress() }
  func navigate(to url: URL) { activeTab.navigate(to: url) }
  func goBack() { activeTab.goBack() }
  func goForward() { activeTab.goForward() }
  func reloadOrStop() { activeTab.reloadOrStop() }
  func openInDefaultBrowser() { activeTab.openInDefaultBrowser() }
  func openExternally(in target: NativeBrowserExternalTarget) { activeTab.openExternally(in: target) }
  func dismissError() { activeTab.dismissError() }

  func suspendPlayback() {
    for tab in tabs { tab.suspendPlayback() }
  }

  func focusAddress() { addressFocusRequest &+= 1 }

  @discardableResult
  func newTab() -> NativeBrowserTab {
    let tab = makeTab()
    tabs.append(tab)
    activeTabID = tab.id
    addressFocusRequest &+= 1
    return tab
  }

  @discardableResult
  func openTab(with request: URLRequest) -> NativeBrowserTab? {
    guard let url = request.url, NativeBrowserAddress.permits(url) else { return nil }
    let tab = makeTab()
    tabs.append(tab)
    activeTabID = tab.id
    tab.load(request)
    return tab
  }

  func selectTab(_ id: UUID) {
    guard tabs.contains(where: { $0.id == id }) else { return }
    activeTabID = id
  }

  func selectNextTab() {
    guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
    selectTab(tabs[(index + 1) % tabs.count].id)
  }

  func selectPreviousTab() {
    guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
    selectTab(tabs[(index + tabs.count - 1) % tabs.count].id)
  }

  func closeTab(_ id: UUID) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
    guard tabs.count > 1 else {
      tabs[0].reset()
      activeTabID = tabs[0].id
      addressFocusRequest &+= 1
      return
    }
    let closingActive = activeTabID == id
    let tab = tabs.remove(at: index)
    tab.teardown()
    if closingActive {
      activeTabID = tabs[min(index, tabs.count - 1)].id
    }
  }

  func closeActiveTab() { closeTab(activeTabID) }
  func closePage() { closeActiveTab() }

  func setPresentation(_ presentation: NativeBrowserPresentation) {
    guard self.presentation != presentation else { return }
    activeHostSequence = 0
    self.presentation = presentation
  }

  func makeHostSequence() -> UInt64 {
    nextHostSequence += 1
    return nextHostSequence
  }

  func claimHost(sequence: UInt64, tabID: UUID, presentation: NativeBrowserPresentation) -> Bool {
    guard self.presentation == presentation, tabID == activeTabID, sequence >= activeHostSequence else { return false }
    activeHostSequence = sequence
    return true
  }

  func shutdown() {
    for tab in tabs { tab.teardown() }
  }

  private func makeTab() -> NativeBrowserTab {
    let tab = NativeBrowserTab(openExternal: openExternal, createWebView: createWebView)
    tab.owner = self
    return tab
  }
}
