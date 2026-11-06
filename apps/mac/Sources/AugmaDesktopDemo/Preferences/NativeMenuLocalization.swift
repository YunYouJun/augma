import AppKit

/// SwiftUI commands update their own labels. AppKit's standard menus need an explicit
/// title update; retaining each menu item preserves its responder action and shortcut.
@MainActor
final class NativeMenuLocalization {
  private let keys = NSMapTable<NSMenuItem, NSString>.weakToStrongObjects()
  private var observers: [NSObjectProtocol] = []
  private var deferredRefresh: Task<Void, Never>?
  private var isRefreshing = false
  private static let standardKeys = [
    "文件", "编辑", "显示", "窗口", "帮助", "设置…", "新建窗口", "关闭窗口", "撤销", "重做",
    "剪切", "复制", "粘贴", "全选", "最小化", "缩放", "前置全部窗口", "进入全屏幕", "退出全屏幕",
    "隐藏其他", "显示全部",
  ]

  func start() {
    guard observers.isEmpty else { return }
    for name in [Notification.Name.augmaAppLanguageChanged, NSMenu.didBeginTrackingNotification,
                 NSMenu.didAddItemNotification, NSMenu.didChangeItemNotification, NSApplication.didBecomeActiveNotification] {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.scheduleRefresh() }
      })
    }
    scheduleRefresh()
  }

  private func scheduleRefresh() {
    guard !isRefreshing else { return }
    refresh()
    deferredRefresh?.cancel()
    // SwiftUI recreates standard menu items when its commands update. Refresh those
    // new objects after that render pass as well as updating the current items now.
    deferredRefresh = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
      self?.refresh()
    }
  }

  func refresh(_ menu: NSMenu? = nil) {
    guard !isRefreshing, let menu = menu ?? NSApp?.mainMenu else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    var sourceKeys: [String: String] = [:]
    for key in Self.standardKeys {
      sourceKeys[key] = key
      for language in ["zh-CN", "en-US", "ja-JP"] {
        sourceKeys[NativeLocalization.string(key, language: language)] = key
      }
    }
    func update(_ menu: NSMenu) {
      for item in menu.items {
        let key = keys.object(forKey: item).map(String.init) ?? sourceKeys[item.title]
        if let key {
          keys.setObject(key as NSString, forKey: item)
          let title = NativeLocalization.string(key)
          if item.title != title { item.title = title }
          if let submenu = item.submenu, submenu.title != title { submenu.title = title }
        }
        if let action = item.action.map(NSStringFromSelector) {
          switch action {
          case "orderFrontStandardAboutPanel:":
            let title = String(appLocalized: "关于 Augma"); if item.title != title { item.title = title }
          case "hide:":
            let title = String(appLocalized: "隐藏 Augma"); if item.title != title { item.title = title }
          case "terminate:":
            let title = String(appLocalized: "退出 Augma"); if item.title != title { item.title = title }
          default: break
          }
        }
        if let submenu = item.submenu { update(submenu) }
      }
    }
    update(menu)
  }

  isolated deinit {
    deferredRefresh?.cancel()
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
