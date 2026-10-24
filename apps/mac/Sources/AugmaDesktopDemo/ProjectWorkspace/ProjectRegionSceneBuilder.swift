import AppKit
import RealityKit

@MainActor
final class ProjectRegionSceneBuilder {
  private struct Node {
    let root: Entity
    let platform: ModelEntity
    let label: Entity
    let signature: String
    var selected = false
  }
  let anchor = AnchorEntity(world: .zero)
  private let camera = PerspectiveCamera()
  private let light = DirectionalLight()
  private let fill = DirectionalLight()
  private let cube = MeshResource.generateBox(size: 1, cornerRadius: 0.04)
  private var nodes: [UUID: Node] = [:]
  private let applications = SystemInstalledApplicationClient()

  init() {
    anchor.addChild(camera); anchor.addChild(light); anchor.addChild(fill)
    camera.camera = PerspectiveCameraComponent(near: 0.1, far: 80, fieldOfViewInDegrees: 48)
    light.look(at: .zero, from: [-4, 10, 7], relativeTo: nil)
    light.shadow = DirectionalLightComponent.Shadow()
    fill.look(at: .zero, from: [6, 5, -5], relativeTo: nil)
    box(anchor, size: [14, 0.2, 8.8], at: [0, -0.18, 0], color: color(0x607B8B))
    for slot in 0..<ProjectRegion.capacity {
      box(anchor, size: [4, 0.08, 3.3], at: [Float(slot % 3) * 4.6 - 4.6, -0.04, Float(slot / 3) * 4 - 2], color: color(0xCFDCD3))
    }
  }

  func update(_ regions: [ProjectRegion], selectedID: UUID?, preferences: NativeScenePreferences, yaw: Double, pitch: Double, scale: Double) {
    let ids = Set(regions.map(\.id))
    for id in Set(nodes.keys).subtracting(ids) { nodes.removeValue(forKey: id)?.root.removeFromParent() }
    for region in regions {
      let signature = region.name + (region.editor?.path ?? "") + (region.browser?.path ?? "")
      if nodes[region.id]?.signature != signature {
        nodes.removeValue(forKey: region.id)?.root.removeFromParent()
        nodes[region.id] = makeRegion(region, signature: signature)
      }
      guard var node = nodes[region.id] else { continue }
      node.root.position = region.position * SIMD3<Float>(preferences.mirror ? -1 : 1, 1, 1)
      if node.selected != (region.id == selectedID) {
        node.selected = region.id == selectedID
        node.platform.model?.materials = [SimpleMaterial(color: color(node.selected ? 0xF2CA75 : 0xDFE9E3), isMetallic: false)]
        nodes[region.id] = node
      }
    }
    light.light.intensity = preferences.dark ? 1_500 : 2_800
    fill.light.intensity = preferences.dark ? 800 : 1_300
    setCamera(yaw: yaw, pitch: pitch, scale: scale)
  }

  func setCamera(yaw: Double, pitch: Double, scale: Double) {
    let azimuth = Float(yaw) + 0.2
    let elevation = min(1.3, max(0.35, Float(pitch) + 0.95))
    let radius = 18 / Float(scale)
    let target: SIMD3<Float> = [0, 0.4, 0]
    let eye = target + SIMD3<Float>(sin(azimuth) * cos(elevation) * radius, sin(elevation) * radius, cos(azimuth) * cos(elevation) * radius)
    camera.look(at: target, from: eye, relativeTo: nil)
    for node in nodes.values { node.label.look(at: eye, from: node.label.position(relativeTo: nil), relativeTo: nil, forward: .positiveZ) }
  }

  private func makeRegion(_ region: ProjectRegion, signature: String) -> Node {
    let root = Entity(); root.name = "project:" + region.id.uuidString; anchor.addChild(root)
    let platform = box(root, size: [4, 0.12, 3.3], at: [0, 0.06, 0], color: color(0xDFE9E3))
    for (x, height, tint, binding) in [(Float(-0.95), Float(1.7), UInt32(0x578CB1), region.editor), (Float(0.95), Float(1.3), UInt32(0x76A997), region.browser)] {
      box(root, size: [1.2, height, 1.3], at: [x, height / 2 + 0.14, 0], color: color(tint))
      box(root, size: [1.35, 0.12, 1.45], at: [x, height + 0.2, 0], color: color(0xE2ECED))
      for row in 0..<3 {
        for column in 0..<3 {
          box(root, size: [0.2, 0.18, 0.03], at: [x - 0.38 + Float(column) * 0.38, 0.4 + Float(row) * 0.34, 0.66], color: color(0xBDE1E3))
        }
      }
      if let binding, let app = applications.resolve(binding.building) {
        let icon = applications.icon(for: app)
        if let image = icon.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let texture = try? TextureResource(image: image, options: .init(semantic: .color)) {
          var material = UnlitMaterial(); material.color = .init(tint: .white, texture: .init(texture))
          let logo = ModelEntity(mesh: .generatePlane(width: 0.55, height: 0.55), materials: [material])
          logo.position = [x, height + 0.56, 0.05]; root.addChild(logo)
        }
      }
    }
    box(root, size: [0.7, 0.45, 0.45], at: [0, 0.36, 1.02], color: color(0xE4BD69))
    box(root, size: [0.28, 0.1, 0.4], at: [-0.18, 0.61, 1.02], color: color(0xE4BD69))
    root.generateCollisionShapes(recursive: true)
    let label = Entity(); label.position = [0, 2.65, 0]; root.addChild(label)
    let plate = box(label, size: [3.8, 0.55, 0.04], at: .zero, color: color(0x294255))
    plate.generateCollisionShapes(recursive: false)
    let mesh = MeshResource.generateText(String(region.name.prefix(24)), extrusionDepth: 0.001, font: .systemFont(ofSize: 0.25, weight: .semibold))
    let title = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
    let bounds = title.visualBounds(relativeTo: title)
    let factor = min(1, 3.4 / max(bounds.extents.x, 0.001))
    title.scale = SIMD3(repeating: factor)
    title.position = [-bounds.center.x * factor, -bounds.center.y * factor, 0.03]
    label.addChild(title)
    return Node(root: root, platform: platform, label: label, signature: signature)
  }
  @discardableResult private func box(_ parent: Entity, size: SIMD3<Float>, at: SIMD3<Float>, color: NSColor) -> ModelEntity {
    let model = ModelEntity(mesh: cube, materials: [SimpleMaterial(color: color, roughness: 0.65, isMetallic: false)])
    model.scale = size; model.position = at; parent.addChild(model); return model
  }
  private func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
  }
}
