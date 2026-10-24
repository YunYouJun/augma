import SwiftUI

/// Main-window composition. The store owns the scene, so changing layout or
/// moving to immersive mode never restarts a scan or simulated route.
struct NativeSpaceView: View {
  @ObservedObject var store: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore

  var body: some View {
    GeometryReader { geometry in
      if !preferences.value.showHud {
        preview
          .padding(16)
      } else if geometry.size.width >= 760 {
        HStack(spacing: 0) {
          preview
            .padding(16)
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
          Divider()
          NativeSpaceControlsView(store: store, preferences: preferences)
            .frame(width: 360)
        }
      } else {
        Form {
          Section {
            preview
              .frame(height: min(420, max(260, geometry.size.height * 0.48)))
          }
          NativeSpaceControlSections(store: store, preferences: preferences)
        }
        .formStyle(.grouped)
      }
    }
  }

  private var preview: some View {
    NativeSpaceCanvas(store: store, preferences: preferences)
      .accessibilityIdentifier("native-space-preview")
      .overlay(alignment: .topLeading) {
        VStack(alignment: .leading, spacing: 3) {
          Text(store.scene.title(locale: preferences.locale))
            .font(.headline)
          Text(store.sceneID == .projects ? "本机项目工作区" : store.sceneID == .workspace ? "本机应用工作区" : "原生模拟空间")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .padding(12)
        .allowsHitTesting(false)
      }
      .overlay(alignment: .bottomLeading) {
        Text("拖动旋转 · 滚动缩放")
          .font(.caption)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(.regularMaterial, in: Capsule())
          .padding(12)
          .allowsHitTesting(false)
      }
      .overlay(alignment: .topTrailing) {
        if !preferences.value.showHud {
          Button("显示 HUD", systemImage: "eye") {
            preferences.set("showHud", value: true)
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("native-space-show-hud")
          .padding(12)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}
