import RealityKit
import SwiftUI

struct DemoSceneView: View {
  var body: some View {
    RealityView { content in
      let platform = ModelEntity(
        mesh: .generateBox(size: 1),
        materials: [SimpleMaterial(color: .init(red: 0.17, green: 0.31, blue: 0.36, alpha: 1), isMetallic: false)]
      )
      platform.scale = [2.5, 0.04, 1.4]
      platform.position = [0, -0.42, 0]
      content.add(platform)

      for (index, x) in [-0.7, 0.0, 0.7].enumerated() {
        let marker = ModelEntity(
          mesh: .generateSphere(radius: 0.12),
          materials: [SimpleMaterial(color: index == 1 ? .cyan : .white, isMetallic: false)]
        )
        marker.position = [Float(x), -0.05, 0]
        content.add(marker)
      }
    }
    .realityViewCameraControls(.orbit)
    .overlay(alignment: .bottomLeading) {
      Text("模拟空间 · 拖动以旋转视角")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
    }
    .background(Color.black.opacity(0.2))
  }
}
