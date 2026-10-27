import SwiftUI

struct NativeStartupSettingsView: View {
  @ObservedObject var store: NativeNavigationStore
  @ObservedObject var sessions: DemoSessionRegistry

  var body: some View {
    Section("首页与启动") {
      Picker("启动时显示", selection: $store.startupMode) {
        Text("恢复上次位置").tag(NativeStartupMode.resume)
        Text("指定首页").tag(NativeStartupMode.home)
      }
      .accessibilityIdentifier("startup-mode")
      Picker("首页页面", selection: $store.homeModule) {
        ForEach(DemoModule.allCases) { module in Text(module.title).tag(module) }
      }
      .accessibilityIdentifier("home-module")
      if store.homeModule == .space {
        Picker("首页 3D 场景", selection: $store.homeSpaceScene) {
          ForEach(NativeSpaceScene.catalog) { scene in
            Text(scene.title(locale: Locale.current.identifier)).tag(scene.id)
          }
        }
        .accessibilityIdentifier("home-space-scene")
      }
      Button("将当前页面设为首页") {
        if let location = sessions.current?.pageLocation { store.setHome(location) }
      }
      .disabled(sessions.current == nil)
      Text("恢复上次活动窗口的页面和 3D 场景，首次使用进入应用街区。首页偏好在之后新开的窗口生效；工具栏的首页按钮可随时返回指定首页。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}
