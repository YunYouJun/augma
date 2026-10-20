import AppKit
import SwiftUI
import WebKit

struct DemoWebView: NSViewRepresentable {
  @Binding var selection: DemoModule?
  @Binding var loadError: String?
  var immersive = false
  var onOverlayRegionsChanged: ((OverlayRegions) -> Void)?

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let initialModule = selection?.rawValue ?? ""
    // Hand the page the app's UI language so the embedded demo matches the native menus.
    let appLocale = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
    let voiceShortcut = Coordinator.javaScriptLiteral(VoiceShortcut.currentChord())
    configuration.userContentController.addUserScript(WKUserScript(
      source: "window.__AUGMA_DESKTOP_MODULE__ = '\(initialModule)'; window.__AUGMA_DESKTOP_LOCALE__ = '\(appLocale)'; window.__AUGMA_DESKTOP_VOICE_SHORTCUT__ = \(voiceShortcut);",
      injectionTime: .atDocumentStart,
      forMainFrameOnly: true
    ))
    if immersive {
      configuration.userContentController.addUserScript(WKUserScript(
        source: "window.__AUGMA_DESKTOP_IMMERSIVE__ = true;",
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
      ))
      configuration.userContentController.addUserScript(WKUserScript(
        source: Self.overlayRegionsScript,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
      ))
      configuration.userContentController.add(context.coordinator, name: "overlayRegions")
    }
    configuration.userContentController.add(context.coordinator, name: "moduleSelection")
    configuration.userContentController.add(context.coordinator, name: "speechCommand")
    let demoURL = Bundle.main.resourceURL?.appendingPathComponent("ar", isDirectory: true)
    if let demoURL {
      configuration.setURLSchemeHandler(DemoResourceSchemeHandler(rootURL: demoURL), forURLScheme: DemoResourceSchemeHandler.scheme)
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)
    context.coordinator.webView = webView
    webView.navigationDelegate = context.coordinator
    if immersive {
      webView.underPageBackgroundColor = .clear
      // WebKit still paints an opaque page background unless its macOS background drawing is disabled.
      let selector = NSSelectorFromString("_setDrawsBackground:")
      if webView.responds(to: selector) {
        typealias SetDrawsBackground = @convention(c) (AnyObject, Selector, Bool) -> Void
        let setter = unsafeBitCast(webView.method(for: selector), to: SetDrawsBackground.self)
        setter(webView, selector, false)
      }
    }

    guard let demoURL else {
      loadError = String(localized: "App 缺少资源目录，请运行 ./script/build_and_run.sh 重新构建。")
      return webView
    }
    let indexURL = demoURL.appendingPathComponent("index.html")
    guard FileManager.default.fileExists(atPath: indexURL.path) else {
      loadError = String(localized: "找不到内置 demo 页面，请运行 ./script/build_and_run.sh 重新构建。")
      return webView
    }
    webView.load(URLRequest(url: DemoResourceSchemeHandler.startURL))
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self
    context.coordinator.select(selection, in: webView)
  }

  static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
    coordinator.cancelSpeech()
    coordinator.unregisterObservers()
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "speechCommand")
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "moduleSelection")
    if coordinator.parent.immersive {
      webView.configuration.userContentController.removeScriptMessageHandler(forName: "overlayRegions")
    }
  }

  private static let overlayRegionsScript = """
    (() => {
      const interactiveSelector = '.device-window, .system-bar button, .device-dock .orb-button, .world-marker, .map-legend, .standby-view, .agm-dialog, .agm-toast';
      const panelSelector = '.device-window';
      const rects = (selector) => Array.from(document.querySelectorAll(selector))
        .filter((element) => {
          const style = getComputedStyle(element);
          return style.display !== 'none' && style.visibility !== 'hidden';
        })
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return [rect.x, rect.y, rect.width, rect.height];
        })
        .filter((rect) => rect[2] > 0 && rect[3] > 0);
      let scheduled = false;
      const send = () => {
        scheduled = false;
        window.webkit.messageHandlers.overlayRegions.postMessage({
          interactive: rects(interactiveSelector),
          panels: rects(panelSelector),
        });
      };
      const schedule = () => {
        if (!scheduled) {
          scheduled = true;
          requestAnimationFrame(send);
        }
      };
      new MutationObserver(schedule).observe(document.documentElement, {
        subtree: true, childList: true, attributes: true,
        attributeFilter: ['class', 'style', 'aria-expanded'],
      });
      new ResizeObserver(schedule).observe(document.documentElement);
      window.addEventListener('resize', schedule);
      window.addEventListener('scroll', schedule, true);
      schedule();
    })();
    """

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: DemoWebView
    weak var webView: WKWebView?
    private var ready = false
    private var lastSelection: DemoModule?
    private var interpretationTask: Task<Void, Never>?
    private var interpretationGeneration = 0
    private lazy var speech = SpeechCommandRecognizer { [weak self] type, text, code in
      self?.sendSpeechEvent(type: type, text: text, code: code)
    }

    init(_ parent: DemoWebView) {
      self.parent = parent
      super.init()
      NotificationCenter.default.addObserver(self, selector: #selector(toggleSpeechFromShortcut), name: .augmaToggleSpeech, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(cancelSpeechForModeChange), name: .augmaCancelSpeech, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(cancelSpeechOnDeactivation), name: NSApplication.didResignActiveNotification, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(sendSpeechConfig), name: .augmaDeepSeekConfigChanged, object: nil)
      // Picks up a key changed under App Shortcuts while the user was in System Settings.
      NotificationCenter.default.addObserver(self, selector: #selector(sendVoiceShortcut), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    func unregisterObservers() {
      NotificationCenter.default.removeObserver(self, name: .augmaToggleSpeech, object: nil)
      NotificationCenter.default.removeObserver(self, name: .augmaCancelSpeech, object: nil)
      NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
      NotificationCenter.default.removeObserver(self, name: .augmaDeepSeekConfigChanged, object: nil)
      NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func toggleSpeechFromShortcut(_ notification: Notification) {
      guard let webView, webView.window?.isVisible == true else { return }
      webView.evaluateJavaScript("window.dispatchEvent(new Event('augma:toggle-speech'))")
    }

    @objc private func cancelSpeechForModeChange(_ notification: Notification) {
      cancelSpeech()
      sendSpeechEvent(type: "cancelled", text: nil)
    }

    @objc private func cancelSpeechOnDeactivation(_ notification: Notification) {
      guard speech.isRecording || interpretationTask != nil else { return }
      cancelSpeechForModeChange(notification)
    }

    func cancelSpeech() {
      speech.cancel()
      interpretationGeneration += 1
      interpretationTask?.cancel()
      interpretationTask = nil
    }

    @objc private func sendSpeechConfig() {
      sendSpeechEvent(type: "config", text: nil, enabled: DeepSeekSettings.isReady)
    }

    /// Tell the page the voice menu item's current key, so its shortcut sheet and command panel show it.
    @objc private func sendVoiceShortcut() {
      guard ready, let webView else { return }
      let value = Self.javaScriptLiteral(VoiceShortcut.currentChord())
      webView.evaluateJavaScript("window.__AUGMA_DESKTOP_VOICE_SHORTCUT__ = \(value); window.dispatchEvent(new CustomEvent('augma:voice-shortcut', { detail: { shortcut: \(value) } }))")
    }

    /// - Returns: The string as a JSON literal, or `null`
    nonisolated static func javaScriptLiteral(_ value: String?) -> String {
      guard let value, let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
            let literal = String(data: data, encoding: .utf8) else { return "null" }
      return literal
    }

    private func sendSpeechEvent(type: String, text: String?, code: String? = nil, enabled: Bool? = nil) {
      var detail: [String: Any] = ["type": type]
      if let text { detail["text"] = text }
      if let code { detail["code"] = code }
      if let enabled { detail["enabled"] = enabled }
      guard let data = try? JSONSerialization.data(withJSONObject: detail),
            let json = String(data: data, encoding: .utf8) else { return }
      webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('augma:speech', { detail: \(json) }))")
    }

    private func interpret(_ value: Any?) {
      guard DeepSeekSettings.isReady, let key = DeepSeekKeychain.load() else {
        sendSpeechEvent(type: "error", text: nil, code: "deepseekNotConfigured")
        return
      }
      let messages: [[String: String]]
      do {
        messages = try DeepSeekClient.validate(value)
      } catch {
        sendSpeechEvent(type: "error", text: nil, code: DeepSeekClient.Failure.invalidInput.code)
        return
      }
      interpretationTask?.cancel()
      interpretationGeneration += 1
      let session = interpretationGeneration
      interpretationTask = Task { [weak self] in
        do {
          let content = try await DeepSeekClient.complete(messages, apiKey: key)
          guard let self, self.interpretationGeneration == session, !Task.isCancelled else { return }
          self.interpretationTask = nil
          self.sendSpeechEvent(type: "interpreted", text: content)
        } catch {
          guard let self, self.interpretationGeneration == session, !Task.isCancelled else { return }
          self.interpretationTask = nil
          if let failure = error as? DeepSeekClient.Failure {
            self.sendSpeechEvent(type: "error", text: failure.detail, code: failure.code)
          } else {
            self.sendSpeechEvent(type: "error", text: error.localizedDescription, code: "deepseekRequest")
          }
        }
      }
    }

    func select(_ module: DemoModule?, in webView: WKWebView) {
      guard ready, module != lastSelection else { return }
      lastSelection = module
      let value = module.map { "'\($0.rawValue)'" } ?? "null"
      webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('augma:select-module', { detail: { module: \(value) } }))")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      ready = true
      parent.loadError = nil
      select(parent.selection, in: webView)
      sendSpeechConfig()
      sendVoiceShortcut()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.loadError = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      parent.loadError = error.localizedDescription
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
      guard navigationAction.navigationType == .linkActivated,
            let url = navigationAction.request.url else {
        return .allow
      }
      if url.scheme == DemoResourceSchemeHandler.scheme, url.path == "/components/",
         let docsURL = URL(string: "https://augma.yyj.moe/components/") {
        NSWorkspace.shared.open(docsURL)
        return .cancel
      } else if url.scheme == "https" || url.scheme == "http" {
        NSWorkspace.shared.open(url)
        return .cancel
      } else {
        return .allow
      }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      if message.name == "speechCommand" {
        guard message.frameInfo.isMainFrame,
              message.webView?.url?.scheme == DemoResourceSchemeHandler.scheme else { return }
        if let action = message.body as? String {
          switch action {
          case "start": Task { await speech.start() }
          case "stop": speech.stop()
          case "cancel": cancelSpeech()
          case "config": sendSpeechConfig()
          default: break
          }
        } else if let body = message.body as? [String: Any] {
          switch body["action"] as? String {
          case "start": Task { await speech.start(localeIdentifier: body["locale"] as? String) }
          case "interpret": interpret(body["messages"])
          default: break
          }
        }
        return
      }
      if message.name == "overlayRegions" {
        guard let body = message.body as? [String: Any] else { return }
        parent.onOverlayRegionsChanged?(OverlayRegions(
          interactive: Self.rects(body["interactive"]),
          panels: Self.rects(body["panels"])
        ))
        return
      }
      guard message.name == "moduleSelection" else { return }
      if message.body is NSNull {
        lastSelection = nil
        parent.selection = nil
      } else if let id = message.body as? String, let module = DemoModule(rawValue: id) {
        lastSelection = module
        parent.selection = module
      }
    }

    private static func rects(_ value: Any?) -> [CGRect] {
      guard let arrays = value as? [[NSNumber]] else { return [] }
      return arrays.compactMap { values in
        guard values.count == 4 else { return nil }
        return CGRect(x: values[0].doubleValue, y: values[1].doubleValue,
                      width: values[2].doubleValue, height: values[3].doubleValue)
      }
    }
  }
}

struct OverlayRegions {
  let interactive: [CGRect]
  let panels: [CGRect]
}

extension Notification.Name {
  static let augmaToggleSpeech = Notification.Name("cn.yunyoujun.augma.toggle-speech")
  static let augmaCancelSpeech = Notification.Name("cn.yunyoujun.augma.cancel-speech")
}
