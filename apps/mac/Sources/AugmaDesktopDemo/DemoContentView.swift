import SwiftUI

struct DemoContentView: View {
  @AppStorage("demoWindowAlwaysOnTop") private var alwaysOnTop = false
  let enterImmersive: (Binding<DemoModule?>) -> Void
  @State private var selection: DemoModule? = .weather
  @State private var loadError: String?

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section("应用") {
          ForEach(DemoModule.dock) { module in
            Label(module.title, systemImage: module.symbol)
              .tag(module)
          }
        }
        Section("系统") {
          ForEach(DemoModule.system) { module in
            Label(module.title, systemImage: module.symbol)
              .tag(module)
          }
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("Augma")
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    } detail: {
      ZStack {
        DemoWebView(selection: $selection, loadError: $loadError)
        if let loadError {
          ContentUnavailableView("无法载入演示", systemImage: "exclamationmark.triangle", description: Text(loadError))
            .background(.regularMaterial)
        }
      }
      .navigationTitle("Augma Demo")
    }
    .navigationSplitViewStyle(.balanced)
    .frame(minWidth: 840, minHeight: 580)
    .background {
      DemoWindowLevelView(alwaysOnTop: alwaysOnTop)
        .frame(width: 0, height: 0)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Toggle(isOn: $alwaysOnTop) {
          Label("始终置顶", systemImage: "pin")
        }
        .toggleStyle(.button)
        .help("让演示窗口始终显示在其他普通窗口上方")
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          enterImmersive($selection)
        } label: {
          Label("沉浸模式", systemImage: "rectangle.inset.filled.and.person.filled")
        }
        .help("将透明界面悬浮在桌面上")
      }
    }
  }
}
