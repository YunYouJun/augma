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
      .safeAreaInset(edge: .bottom) { SidebarBrand() }
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
    .tint(.augmaAccent)
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

private struct SidebarBrand: View {
  var body: some View {
    HStack(spacing: 10) {
      AugmaRing(size: 28)
      VStack(alignment: .leading, spacing: 1) {
        Text("Augma")
          .font(.system(size: 13, weight: .semibold))
        Text("界面，浮现于现实。")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.augmaAccent)
        .frame(width: 24, height: 2)
        .shadow(color: Color.augmaHighlight.opacity(0.5), radius: 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14)
    }
  }
}
