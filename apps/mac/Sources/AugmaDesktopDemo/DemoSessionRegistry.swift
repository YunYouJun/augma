import AppKit
import OSLog

/// Routes menu-bar actions to the last active main window, including while another app is active.
@MainActor
final class DemoSessionRegistry: ObservableObject {
  enum Request { case open(DemoModule?), voice, space(NativeSpaceAction) }
  @Published private(set) var current: NativeDemoModel?
  private var sessions: [WeakSession] = []
  private var pending: Request?
  private let logger = Logger(subsystem: "cn.yunyoujun.augma.desktop-demo", category: "menu-bar")

  func register(_ model: NativeDemoModel) {
    sessions.removeAll { $0.model == nil || $0.model === model }
    sessions.append(WeakSession(model))
    current = model
    model.activateNavigation()
    if let pending {
      self.pending = nil
      apply(pending, to: model)
    }
  }

  func activate(_ model: NativeDemoModel) {
    sessions.removeAll { $0.model == nil || $0.model === model }
    sessions.append(WeakSession(model))
    if current !== model { current = model }
    model.activateNavigation()
  }

  func unregister(_ model: NativeDemoModel) {
    sessions.removeAll { $0.model == nil || $0.model === model }
    if current === model {
      current = sessions.last?.model
      current?.activateNavigation()
    }
  }

  func perform(_ request: Request, openWindow: () -> Void) {
    if let model = current, let window = model.window {
      NSApp.activate(ignoringOtherApps: true)
      window.deminiaturize(nil)
      window.makeKeyAndOrderFront(nil)
      apply(request, to: model)
      logger.info("Routed menu action to existing main window")
    } else {
      pending = request
      openWindow()
      NSApp.activate(ignoringOtherApps: true)
      logger.info("Opened main window for menu action")
    }
  }

  private func apply(_ request: Request, to model: NativeDemoModel) {
    switch request {
    case .open(let module):
      if let module {
        model.selection = module
        model.preferences.value.showHud = true
      }
      if model.selection == .space { model.preferences.value.showHud = true }
    case .voice:
      model.toggleSpeech()
    case .space(let action):
      model.performSpaceAction(action)
    }
  }

  private final class WeakSession {
    weak var model: NativeDemoModel?
    init(_ model: NativeDemoModel) { self.model = model }
  }
}
