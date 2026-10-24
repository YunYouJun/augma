import AppKit
import RealityKit
import simd

/// A bounded, static neighborhood. State changes recolor indicators instead of rebuilding the city.
@MainActor
final class ApplicationDistrictSceneBuilder {
  struct BuildingNode {
    let root: Entity
    let badge: Entity
    let pedestal: ModelEntity
    let beacon: ModelEntity
    let windows: [ModelEntity]
    var title: String
    var icon: NSImage?
    var selected = false
  }

  let anchor = AnchorEntity(world: .zero)
  private let world = Entity()
  private let camera = PerspectiveCamera()
  private let light = DirectionalLight()
  private let fill = DirectionalLight()
  private let cube = MeshResource.generateBox(size: 1, cornerRadius: 0.025)
  private var nodes: [String: BuildingNode] = [:]
  private var statusCache: [String: ApplicationRunState] = [:]
  private var mirrored = false
  private var eye: SIMD3<Float> = [7, 9, 12]

  init() {
    anchor.addChild(world)
    anchor.addChild(camera)
    anchor.addChild(light)
    anchor.addChild(fill)
    camera.camera = PerspectiveCameraComponent(near: 0.1, far: 60, fieldOfViewInDegrees: 48)
    light.light.intensity = 2_800
    light.shadow = DirectionalLightComponent.Shadow()
    light.look(at: .zero, from: [-4, 9, 5], relativeTo: nil)
    fill.light.intensity = 1_200
    fill.look(at: .zero, from: [5, 4, -4], relativeTo: nil)
    box(world, size: [10.8, 0.18, 8.6], at: [0, -0.15, 0], color: color(0x374E65))
    box(world, size: [10.6, 0.04, 8.4], at: [0, -0.04, 0], color: color(0xA4B5BD))
    for x: Float in [-4.8, -2.4, 0, 2.4, 4.8] {
      box(world, size: [0.34, 0.015, 8.3], at: [x, 0, 0], color: color(0x5E7588))
    }
    for z: Float in [-3.75, -1.25, 1.25, 3.75] {
      box(world, size: [10.5, 0.015, 0.32], at: [0, 0, z], color: color(0x5E7588))
    }
    // Vacant plots remain visible so the saved positions are easy to understand.
    for slot in 0..<ApplicationBuilding.capacity {
      let position = SIMD3<Float>(Float(slot % 4) * 2.4 - 3.6, 0.012, Float(slot / 4) * 2.5 - 2.5)
      box(world, size: [1.9, 0.02, 1.9], at: position, color: color(0xBDCEC7))
    }
  }

  func update(buildings: [ApplicationBuilding], states: [String: ApplicationRunState], icons: [String: NSImage],
              selectedID: String?, preferences: NativeScenePreferences, yaw: Double, pitch: Double, scale: Double) {
    let ids = Set(buildings.map(\.id))
    for id in Set(nodes.keys).subtracting(ids) { nodes.removeValue(forKey: id)?.root.removeFromParent(); statusCache[id] = nil }
    mirrored = preferences.mirror
    for building in buildings {
      if nodes[building.id] == nil { nodes[building.id] = makeBuilding(building) }
      guard var node = nodes[building.id] else { continue }
      node.root.position = building.position * SIMD3<Float>(mirrored ? -1 : 1, 1, 1)
      let icon = icons[building.id]
      if node.title != building.title || node.icon !== icon {
        node.badge.children.removeAll()
        makeBadge(node.badge, title: building.title, icon: icon)
        node.title = building.title
        node.icon = icon
        nodes[building.id] = node
      }
      if node.selected != (building.id == selectedID) {
        node.selected = building.id == selectedID
        node.pedestal.model?.materials = [SimpleMaterial(color: color(node.selected ? 0xE9B55A : 0xE5E9E5), isMetallic: false)]
      }
      nodes[building.id] = node
      let status = states[building.id] ?? .stopped
      if statusCache[building.id] != status {
        statusCache[building.id] = status
        let tint = color(status == .frontmost ? 0x56D9EF : status == .running ? 0x76D7A2 : status == .missing ? 0xED9F59 : 0x677A89)
        node.beacon.model?.materials = [UnlitMaterial(color: tint)]
        node.windows.forEach { $0.model?.materials = [UnlitMaterial(color: tint)] }
      }
    }
    light.light.intensity = preferences.dark ? 1_500 : 2_800
    fill.light.intensity = preferences.dark ? 700 : 1_200
    setCamera(yaw: yaw, pitch: pitch, scale: scale)
  }

  func setCamera(yaw: Double, pitch: Double, scale: Double) {
    let azimuth = Float(yaw) + 0.24
    let elevation = min(1.3, max(0.35, Float(pitch) + 0.95))
    let radius = 14.8 / Float(scale)
    let target: SIMD3<Float> = [0, 0.4, 0]
    eye = target + [sin(azimuth) * cos(elevation) * radius, sin(elevation) * radius, cos(azimuth) * cos(elevation) * radius]
    camera.look(at: target, from: eye, relativeTo: nil)
    for node in nodes.values {
      node.badge.look(at: eye, from: node.badge.position(relativeTo: nil), relativeTo: nil, forward: .positiveZ)
    }
  }

  private func makeBuilding(_ building: ApplicationBuilding) -> BuildingNode {
    let root = Entity()
    root.name = "application:" + building.id
    world.addChild(root)
    let hash = building.id.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
    let height = Float(1.2 + Double(hash % 5) * 0.18)
    let colors: [UInt32] = [0x568CB4, 0x599D96, 0x997FAA, 0xBD946C, 0x7B97AD]
    let tint = color(colors[Int(hash % UInt32(colors.count))])
    let pedestal = box(root, size: [1.85, 0.10, 1.85], at: [0, 0.08, 0], color: .white)
    box(root, size: [1.25, height, 1.2], at: [0, height / 2 + 0.14, 0], color: tint)
    box(root, size: [1.36, 0.12, 1.32], at: [0, height + 0.16, 0], color: color(0xDFE8EB))
    box(root, size: [0.46, 0.22, 0.48], at: [0.24, height + 0.31, -0.16], color: tint)
    let beacon = box(root, size: [0.16, 0.16, 0.16], at: [-0.4, height + 0.31, 0.4], color: .gray)
    var windows: [ModelEntity] = []
    for row in 0..<3 {
      for column in 0..<3 {
        windows.append(box(root, size: [0.22, 0.18, 0.025], at: [-0.4 + Float(column) * 0.4, 0.44 + Float(row) * 0.34, 0.615], color: .gray))
        windows.append(box(root, size: [0.025, 0.18, 0.22], at: [0.64, 0.44 + Float(row) * 0.34, -0.4 + Float(column) * 0.4], color: .gray))
      }
    }
    box(root, size: [0.27, 0.34, 0.04], at: [0, 0.31, 0.64], color: color(0x254356))
    root.generateCollisionShapes(recursive: true)
    let badge = Entity()
    badge.position = [0, height + 0.85, 0]
    root.addChild(badge)
    return BuildingNode(root: root, badge: badge, pedestal: pedestal, beacon: beacon,
                        windows: windows, title: "", icon: nil)
  }

  private func makeBadge(_ badge: Entity, title: String, icon: NSImage?) {
    let plate = box(badge, size: [2.05, 0.53, 0.04], at: .zero, color: color(0x243A4B))
    plate.generateCollisionShapes(recursive: false)
    if let icon, let image = icon.cgImage(forProposedRect: nil, context: nil, hints: nil),
       let texture = try? TextureResource(image: image, options: .init(semantic: .color)) {
      var material = UnlitMaterial()
      material.color = .init(tint: .white, texture: .init(texture))
      let picture = ModelEntity(mesh: .generatePlane(width: 0.4, height: 0.4), materials: [material])
      picture.position = [-0.76, 0, 0.027]
      badge.addChild(picture)
    }
    let label = String(title.prefix(18))
    let mesh = MeshResource.generateText(label, extrusionDepth: 0.001, font: .systemFont(ofSize: 0.18, weight: .semibold),
                                         containerFrame: .zero, alignment: .left, lineBreakMode: .byClipping)
    let text = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
    let bounds = text.visualBounds(relativeTo: text)
    let scale = min(1, 1.35 / max(bounds.extents.x, 0.001))
    text.scale = SIMD3<Float>(repeating: scale)
    text.position = [-0.48 - bounds.min.x * scale, -bounds.center.y * scale, 0.028]
    badge.addChild(text)
  }

  @discardableResult private func box(_ parent: Entity, size: SIMD3<Float>, at: SIMD3<Float>, color: NSColor) -> ModelEntity {
    let entity = ModelEntity(mesh: cube, materials: [SimpleMaterial(color: color, roughness: 0.65, isMetallic: false)])
    entity.scale = size
    entity.position = at
    parent.addChild(entity)
    return entity
  }

  private func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
  }
}
