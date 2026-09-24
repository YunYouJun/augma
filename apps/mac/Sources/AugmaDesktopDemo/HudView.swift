import SwiftUI

struct HudView: View {
  @ObservedObject var model: HudModel
  let hideWindow: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("AUGMA")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .tracking(3)
          Text("桌面辅助视界")
            .font(.system(size: 22, weight: .light))
        }
        Spacer()
        Text(model.rendersDemoScene ? "DEMO SPACE" : "STANDBY")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(.top, 3)
      }

      Group {
        if model.rendersDemoScene {
          DemoSceneView()
        } else {
          ZStack {
            Color.primary.opacity(0.04)
            VStack(spacing: 8) {
              Image(systemName: "viewfinder")
                .font(.system(size: 28, weight: .ultraLight))
              Text("默认状态不创建 3D 场景")
                .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 162)
      .clipShape(RoundedRectangle(cornerRadius: 9))

      HStack(spacing: 10) {
        Button(model.wantsDemoScene ? "退出演示空间" : "进入演示空间") {
          if model.wantsDemoScene {
            model.leaveDemoScene()
          } else {
            model.wantsDemoScene = true
          }
        }
        .buttonStyle(.borderedProminent)
        Spacer()
        Button("隐藏窗口", action: hideWindow)
          .buttonStyle(.bordered)
      }
    }
    .padding(20)
    .frame(width: 430, height: 320)
    .foregroundStyle(.primary)
    .tint(.accentColor)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12)))
  }
}
