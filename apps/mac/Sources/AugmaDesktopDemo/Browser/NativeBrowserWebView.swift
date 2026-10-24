import AppKit
import SwiftUI
import WebKit

struct NativeBrowserWebView: NSViewRepresentable {
  @ObservedObject var store: NativeBrowserStore
  let presentation: NativeBrowserPresentation

  func makeNSView(context: Context) -> NativeBrowserWebHost {
    let host = NativeBrowserWebHost(store: store)
    updateNSView(host, context: context)
    return host
  }

  func updateNSView(_ host: NativeBrowserWebHost, context: Context) {
    guard let webView = store.webView else { host.detach(); return }
    host.attach(webView, presentation: presentation)
  }
  static func dismantleNSView(_ host: NativeBrowserWebHost, coordinator: ()) { host.detach() }
}

/// Each presentation owns a host, while the store owns the sole page and navigation history.
@MainActor
final class NativeBrowserWebHost: NSView {
  private weak var store: NativeBrowserStore?
  private let sequence: UInt64
  private weak var hostedWebView: WKWebView?
  private var webConstraints: [NSLayoutConstraint] = []

  init(store: NativeBrowserStore) {
    self.store = store
    sequence = store.makeHostSequence()
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { nil }

  func attach(_ webView: WKWebView, presentation: NativeBrowserPresentation) {
    // A delayed update from the old presentation must never reclaim the shared page.
    // Sequence ordering also covers leaving and reopening the browser in the same mode.
    guard store?.claimHost(sequence: sequence, presentation: presentation) == true else {
      detach()
      return
    }
    guard webView.superview !== self else { return }
    detach()
    if let oldHost = webView.superview as? NativeBrowserWebHost { oldHost.detach() }
    else { webView.removeFromSuperview() }
    hostedWebView = webView
    webView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(webView)
    webConstraints = [
      webView.leadingAnchor.constraint(equalTo: leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: trailingAnchor),
      webView.topAnchor.constraint(equalTo: topAnchor),
      webView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ]
    NSLayoutConstraint.activate(webConstraints)
  }

  func detach() {
    NSLayoutConstraint.deactivate(webConstraints)
    webConstraints.removeAll()
    // SwiftUI can dismantle the former host after the new presentation has attached the page.
    if hostedWebView?.superview === self { hostedWebView?.removeFromSuperview() }
    hostedWebView = nil
  }
}
