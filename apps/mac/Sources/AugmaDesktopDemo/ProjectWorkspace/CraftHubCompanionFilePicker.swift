import AppKit
import UniformTypeIdentifiers

/// Lives with the store so dismissing the menu does not discard a pending selection.
@MainActor
final class CraftHubCompanionFilePicker {
  enum Kind { case summary, application }

  private let makePanel: () -> NSOpenPanel
  private let activate: () -> Void
  private var activePanel: NSOpenPanel?

  init(makePanel: @escaping () -> NSOpenPanel = { NSOpenPanel() },
       activate: @escaping () -> Void = { NSApp.activate(ignoringOtherApps: true) }) {
    self.makePanel = makePanel
    self.activate = activate
  }

  func present(_ kind: Kind, selection: @escaping (URL) -> Void) {
    if let activePanel {
      activate()
      activePanel.makeKeyAndOrderFront(nil)
      return
    }
    let panel = makePanel()
    panel.title = kind == .application ? String(appLocalized: "选择主应用…") : String(appLocalized: "选择摘要…")
    panel.allowedContentTypes = kind == .application ? [.applicationBundle] : [.json]
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    if kind == .application { panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true) }
    activePanel = panel
    activate()
    // A menu-bar action must return to SwiftUI while the system picker loads.
    // runModal() nests an app-modal event loop and stalls the originating popup.
    panel.begin { [weak self] response in
      guard let self, self.activePanel === panel else { return }
      self.activePanel = nil
      if response == .OK, let url = panel.url { selection(url) }
    }
  }
}
