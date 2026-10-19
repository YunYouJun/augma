import SwiftUI

struct HudView: View {
  @ObservedObject var model: HudModel
  let hideWindow: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        AugmaRing(size: 34)
        VStack(alignment: .leading, spacing: 2) {
          Text("AUGMA")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(3)
            .foregroundStyle(.secondary)
          Text("桌面辅助视界")
            .font(.system(size: 20, weight: .light))
        }
        Spacer()
        HStack(spacing: 2) {
          StatusPing(color: model.rendersDemoScene ? .augmaCyan : .secondary, active: model.rendersDemoScene)
          Text(model.rendersDemoScene ? "DEMO SPACE" : "STANDBY")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }

      Group {
        if model.rendersDemoScene {
          DemoSceneView()
        } else {
          ZStack {
            Color.primary.opacity(0.04)
            HStack(spacing: 18) {
              ZStack {
                AugmaRing(size: 96)
                Image(systemName: "viewfinder")
                  .font(.system(size: 22, weight: .ultraLight))
              }
              VStack(alignment: .leading, spacing: 6) {
                Text("演示空间待命")
                  .font(.system(size: 14, weight: .medium))
                Text("默认状态不创建 3D 场景")
                  .font(.system(size: 12))
                  .foregroundStyle(.secondary)
              }
            }
            .foregroundStyle(.primary)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 162)
      .clipShape(RoundedRectangle(cornerRadius: 3))
      .overlay {
        HudBrackets()
          .stroke(Color.augmaHighlight.opacity(0.85), lineWidth: 1.5)
          .padding(-4)
          .allowsHitTesting(false)
      }
      .animation(.augma(), value: model.rendersDemoScene)

      HStack(spacing: 10) {
        Button(model.wantsDemoScene ? "退出演示空间" : "进入演示空间") {
          if model.wantsDemoScene {
            model.leaveDemoScene()
          } else {
            model.wantsDemoScene = true
          }
        }
        .buttonStyle(AugmaButtonStyle())
        Spacer()
        Button("隐藏窗口", action: hideWindow)
          .buttonStyle(AugmaButtonStyle(variant: .outline))
      }
    }
    .padding(20)
    .frame(width: 430, height: 320)
    .foregroundStyle(.primary)
    .tint(.augmaAccent)
    .augmaGlass()
    .augmaMaterialize(active: model.windowVisible)
  }
}
