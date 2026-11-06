import SwiftUI
import WebKit

struct AugmaPluginWebView: NSViewRepresentable {
  let package: AugmaPluginPackage
  @Environment(\.locale) private var locale

  func makeCoordinator() -> AugmaPluginRuntime { AugmaPluginRuntime(package: package, language: locale.identifier) }
  func makeNSView(context: Context) -> WKWebView { context.coordinator.start() }
  func updateNSView(_ view: WKWebView, context: Context) { context.coordinator.setLanguage(locale.identifier) }
  static func dismantleNSView(_ view: WKWebView, coordinator: AugmaPluginRuntime) { coordinator.shutdown() }
}

@MainActor
final class AugmaPluginRuntime: NSObject, WKNavigationDelegate, WKUIDelegate, WKURLSchemeHandler {
  private let resources: AugmaPluginResource
  private(set) var webView: WKWebView?
  private(set) var running = false
  private var language: String
  private var languageUserScript: WKUserScript?

  init(package: AugmaPluginPackage, language: String = NativeLocalization.language) {
    resources = AugmaPluginResource(package: package)
    self.language = language
  }

  func start() -> WKWebView {
    if let webView { return webView }
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.setURLSchemeHandler(self, forURLScheme: AugmaPluginResource.scheme)
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    let languageUserScript = WKUserScript(source: languageScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    self.languageUserScript = languageUserScript
    configuration.userContentController.addUserScript(languageUserScript)
    configuration.userContentController.addUserScript(WKUserScript(source: """
      for (const name of ['geolocation', 'mediaDevices', 'clipboard', 'serviceWorker']) {
        for (const owner of [navigator, Object.getPrototypeOf(navigator)]) {
          try { Object.defineProperty(owner, name, {value: undefined, configurable: false}); } catch {}
        }
      }
      """, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = self; view.uiDelegate = self
    view.setValue(false, forKey: "drawsBackground")
    view.allowsBackForwardNavigationGestures = false
    webView = view; running = true
    view.load(URLRequest(url: resources.entryURL))
    return view
  }

  private var languageScript: String {
    // A JSON string prevents arbitrary script text from becoming executable code.
    let value = String(decoding: try! JSONEncoder().encode(language), as: UTF8.self)
    return "window.augmaLocale = \(value); window.dispatchEvent(new CustomEvent('augma:locale-change', {detail: {locale: \(value)}}));"
  }

  func setLanguage(_ language: String) {
    guard language != self.language else { return }
    self.language = language
    guard let webView else { return }
    // Preserve the current page, exercise, and JavaScript state when language changes.
    let controller = webView.configuration.userContentController
    let retained = controller.userScripts.filter { $0 !== languageUserScript }
    controller.removeAllUserScripts()
    for script in retained { controller.addUserScript(script) }
    let script = WKUserScript(source: languageScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    languageUserScript = script
    controller.addUserScript(script)
    webView.evaluateJavaScript(languageScript, completionHandler: nil)
  }

  func shutdown() {
    running = false
    guard let webView else { return }
    webView.stopLoading()
    webView.navigationDelegate = nil; webView.uiDelegate = nil
    webView.configuration.userContentController.removeAllUserScripts()
    webView.loadHTMLString("", baseURL: nil)
    webView.removeFromSuperview()
    self.webView = nil
  }

  func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
    do {
      guard running, let url = urlSchemeTask.request.url,
            urlSchemeTask.request.httpMethod == nil || urlSchemeTask.request.httpMethod == "GET" else { throw AugmaPluginError.unavailable }
      let resource = try resources.read(url)
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
        "Content-Type": resource.mime + (resource.mime.hasPrefix("text/") ? "; charset=utf-8" : ""),
        "Content-Security-Policy": AugmaPluginResource.contentPolicy, "X-Content-Type-Options": "nosniff",
        "Permissions-Policy": "camera=(), microphone=(), geolocation=(), clipboard-read=(), clipboard-write=()",
      ])!
      urlSchemeTask.didReceive(response); urlSchemeTask.didReceive(resource.data); urlSchemeTask.didFinish()
    } catch { urlSchemeTask.didFailWithError(error) }
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    decisionHandler(running && navigationAction.targetFrame?.isMainFrame == true
      && navigationAction.request.url.map(resources.allows) == true ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }

  func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
               initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
               decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

  @available(macOS 27.0, *)
  func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin,
               initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
}
