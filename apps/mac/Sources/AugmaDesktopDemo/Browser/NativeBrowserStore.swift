import AppKit
import Combine
import WebKit

enum NativeBrowserPresentation {
  case main, immersive
}

/// One user-initiated browsing session, shared by the main window and immersive presentation.
/// This WebKit instance has no Augma script messages, local resource scheme, or injected app state.
@MainActor
final class NativeBrowserStore: NSObject, ObservableObject {
  @Published var addressInput = ""
  @Published private(set) var currentURL: URL?
  @Published private(set) var title = ""
  @Published private(set) var hasPage = false
  @Published private(set) var isLoading = false
  @Published private(set) var progress = 0.0
  @Published private(set) var canGoBack = false
  @Published private(set) var canGoForward = false
  @Published private(set) var error: String?
  @Published private(set) var addressFocusRequest = 0
  @Published private(set) var presentation: NativeBrowserPresentation = .main

  private(set) var webView: WKWebView?
  private var observations: [NSKeyValueObservation] = []
  private let openExternal: (URL) -> Bool
  private let createWebView: (WKWebViewConfiguration) -> WKWebView
  private var nextHostSequence: UInt64 = 0
  private var activeHostSequence: UInt64 = 0

  init(openExternal: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
       createWebView: @escaping (WKWebViewConfiguration) -> WKWebView = { WKWebView(frame: .zero, configuration: $0) }) {
    self.openExternal = openExternal
    self.createWebView = createWebView
    super.init()
  }

  func submitAddress() {
    do { navigate(to: try NativeBrowserAddress.resolve(addressInput)) }
    catch let failure as NativeBrowserAddressError { error = failure.message }
    catch { self.error = String(localized: "网址无效，请检查后重试。") }
  }

  func navigate(to url: URL) {
    guard NativeBrowserAddress.permits(url) else {
      error = String(localized: "仅支持 HTTP 和 HTTPS 网页。")
      return
    }
    error = nil
    addressInput = url.absoluteString
    currentURL = url
    let view = makeWebViewIfNeeded()
    hasPage = true
    view.load(URLRequest(url: url))
  }

  func goBack() {
    guard let webView, webView.canGoBack else { return }
    error = nil
    webView.goBack()
  }

  func goForward() {
    guard let webView, webView.canGoForward else { return }
    error = nil
    webView.goForward()
  }

  func reloadOrStop() {
    guard let webView else { return }
    if webView.isLoading {
      webView.stopLoading()
      isLoading = false
    } else {
      error = nil
      if webView.url != nil { webView.reload() }
      else if let currentURL { webView.load(URLRequest(url: currentURL)) }
    }
  }

  func openInDefaultBrowser() {
    guard let currentURL, NativeBrowserAddress.permits(currentURL) else { return }
    if !openExternal(currentURL) { error = String(localized: "无法在默认浏览器中打开网页。") }
  }

  func dismissError() { error = nil }
  func suspendPlayback() { webView?.pauseAllMediaPlayback() }
  func focusAddress() { addressFocusRequest &+= 1 }

  func setPresentation(_ presentation: NativeBrowserPresentation) {
    guard self.presentation != presentation else { return }
    activeHostSequence = 0
    self.presentation = presentation
  }

  func makeHostSequence() -> UInt64 {
    nextHostSequence += 1
    return nextHostSequence
  }

  func claimHost(sequence: UInt64, presentation: NativeBrowserPresentation) -> Bool {
    guard self.presentation == presentation, sequence >= activeHostSequence else { return false }
    activeHostSequence = sequence
    return true
  }

  func closePage() {
    shutdown()
    addressInput = ""
    currentURL = nil
    title = ""
    hasPage = false
    isLoading = false
    progress = 0
    canGoBack = false
    canGoForward = false
    error = nil
  }

  func shutdown() {
    observations.removeAll()
    webView?.navigationDelegate = nil
    webView?.uiDelegate = nil
    webView?.stopLoading()
    webView?.pauseAllMediaPlayback()
    webView?.removeFromSuperview()
    webView = nil
  }

  private func makeWebViewIfNeeded() -> WKWebView {
    if let webView { return webView }
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    configuration.mediaTypesRequiringUserActionForPlayback = .all
    let view = createWebView(configuration)
    view.navigationDelegate = self
    view.uiDelegate = self
    view.allowsBackForwardNavigationGestures = true
    view.setAccessibilityIdentifier("native-browser-page")
    webView = view

    func observe<Value>(_ keyPath: KeyPath<WKWebView, Value>) {
      observations.append(view.observe(keyPath, options: [.new]) { [weak self, weak view] _, _ in
        Task { @MainActor [weak self, weak view] in
          guard let self, let view, self.webView === view else { return }
          self.refresh(from: view)
        }
      })
    }
    observe(\.title)
    observations.append(view.observe(\.url, options: [.new]) { [weak self, weak view] _, _ in
      Task { @MainActor [weak self, weak view] in
        guard let self, let view, self.webView === view else { return }
        self.updateAddress(from: view)
      }
    })
    observe(\.isLoading)
    observe(\.estimatedProgress)
    observe(\.canGoBack)
    observe(\.canGoForward)
    return view
  }

  private func refresh(from view: WKWebView) {
    title = view.title ?? ""
    isLoading = view.isLoading
    progress = view.estimatedProgress
    canGoBack = view.canGoBack
    canGoForward = view.canGoForward
  }

  private func updateAddress(from view: WKWebView) {
    guard webView === view else { return }
    if let url = view.url, NativeBrowserAddress.permits(url) {
      currentURL = url
      addressInput = url.absoluteString
    }
    refresh(from: view)
  }

  private func navigationFailed(_ failure: Error, view: WKWebView) {
    guard webView === view, (failure as NSError).code != NSURLErrorCancelled else { return }
    isLoading = false
    error = failure.localizedDescription
    refresh(from: view)
  }
}

extension NativeBrowserStore: WKNavigationDelegate, WKUIDelegate {
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
    guard self.webView === webView, let url = navigationAction.request.url else { return .cancel }
    if navigationAction.targetFrame?.isMainFrame == false {
      // A page's blank frames are internal WebKit content, never an app bridge.
      if url.absoluteString == "about:blank" { return .allow }
      return NativeBrowserAddress.permits(url) ? .allow : .cancel
    }
    guard NativeBrowserAddress.permits(url) else {
      error = String(localized: "仅支持 HTTP 和 HTTPS 网页。")
      return .cancel
    }
    if navigationAction.shouldPerformDownload {
      error = String(localized: "请在默认浏览器中下载此文件。")
      return .cancel
    }
    if navigationAction.targetFrame == nil {
      // A user-clicked new-window link reuses this session instead of spawning hidden windows.
      webView.load(navigationAction.request)
      return .cancel
    }
    error = nil
    return .allow
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
    guard self.webView === webView else { return .cancel }
    guard navigationResponse.canShowMIMEType else {
      if navigationResponse.isForMainFrame { error = String(localized: "请在默认浏览器中下载此文件。") }
      return .cancel
    }
    return .allow
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { updateAddress(from: webView) }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { updateAddress(from: webView) }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error, view: webView) }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error, view: webView) }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    guard self.webView === webView else { return }
    isLoading = false
    error = String(localized: "网页进程已结束，请重新载入。")
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if navigationAction.targetFrame == nil, let url = navigationAction.request.url, NativeBrowserAddress.permits(url) {
      webView.load(navigationAction.request)
    }
    return nil
  }

  func webView(_ webView: WKWebView, decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
               initiatedBy frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
    // Browsing does not inherit permission granted to Augma's native camera or voice assistant.
    .deny
  }
}
