import AppKit
import RealityKit
import simd

/// A quiet, faceted floating garden. Geometry is batched by colour and has no textures,
/// collision shapes, frame subscriptions, or external assets.
@MainActor
enum NativeFloatingGarden {
  static func make() -> Entity {
    let root = Entity()
    root.name = "native-floating-garden"
    root.addChild(makeGround())
    makeForeground().attach(to: root, name: "garden-foreground")

    let citadel = Entity()
    citadel.name = "garden-citadel"
    citadel.position = [0, 2.5, -20]
    citadel.scale = SIMD3<Float>(repeating: 1.35)
    makeCitadel().attach(to: citadel, name: "garden-citadel-colours", haze: 0.17)
    root.addChild(citadel)

    let sites: [(SIMD3<Float>, Float, Float)] = [
      ([-3.9, 1.0, -5.9], 0.72, 1.1),
      ([3.8, 1.6, -9.2], 0.92, 1.45),
      ([-5.4, 2.7, -17.3], 0.95, 1.65),
    ]
    for (index, site) in sites.enumerated() {
      let island = Entity()
      island.name = "floating-island-\(index)"
      island.position = site.0
      let shapes = Shapes()
      shapes.rock(radius: site.1, depth: site.2, at: .zero, colour: .rock, sides: 12)
      shapes.cylinder(height: 0.08, bottom: site.1, top: site.1 * 0.98, at: [0, 0.025, 0], colour: .grassLight, sides: 12)
      shapes.tree(at: [-site.1 * 0.15, 0.065, 0], height: site.1 * 1.1)
      if index == 1 {
        shapes.box([0.09, 2.7, 0.025], at: [-0.2, -1.31, site.1 * 0.94], colour: .water)
        shapes.box([0.022, 2.5, 0.029], at: [-0.22, -1.23, site.1 * 0.94 + 0.002], colour: .waterLight)
      }
      shapes.attach(to: island, name: "garden-island-colours-\(index)", haze: Float(index) * 0.08)
      root.addChild(island)
    }

    for (index, location) in [SIMD3<Float>(-4.5, -0.8, -12), [4.6, -0.5, -18.7]].enumerated() {
      let cloud = Entity()
      cloud.name = "clouds-\(index)"
      cloud.position = location
      let shapes = Shapes()
      for lobe in 0..<4 {
        let offset = Float(lobe) - 1.5
        shapes.facetedBlob(
          [3.1 + Float(lobe % 2) * 0.55, 1.0 + Float(lobe % 3) * 0.16, 1.9],
          at: [offset * 1.04, sin(Float(lobe) * 1.7) * 0.13, cos(Float(lobe) * 1.4) * 0.2],
          colour: lobe == 0 ? .cloudShade : .cloud, sides: 8
        )
      }
      shapes.attach(to: cloud, name: "garden-cloud-colours-\(index)")
      root.addChild(cloud)
    }
    return root
  }

  /// The existing central landmark can reuse the same flat-faceted tree language.
  static func makeTree() -> Entity {
    let root = Entity()
    root.name = "garden-landmark-tree"
    let shapes = Shapes()
    shapes.tree(at: .zero, height: 1.4)
    shapes.attach(to: root, name: "garden-landmark-tree-colours")
    return root
  }

  private static func makeGround() -> Entity {
    let foreground = Entity()
    foreground.name = "foreground-island"
    let terrain = Entity()
    terrain.position.z = 1.6
    terrain.scale = [4.4 / 3.7, 1, 1]
    foreground.addChild(terrain)
    let shapes = Shapes()
    shapes.rock(radius: 3.7, depth: 2.2, at: [0, -0.04, 0], colour: .rock, sides: 16)
    shapes.cylinder(height: 0.09, bottom: 3.7, top: 3.7, at: [0, -0.005, 0], colour: .grass, sides: 16)
    shapes.attach(to: terrain, name: "garden-ground-colours")
    // The lawn extends behind the viewer; the bridge and landmark approaches stay in place.
    let paths = Shapes()
    paths.box([0.42, 0.025, 7.3], at: [0.05, 0.057, 1.5], colour: .stoneLight)
    paths.box([4.05, 0.025, 0.40], at: [0, 0.058, 0.28], colour: .stoneLight)
    for index in 0..<12 {
      paths.box([0.4, 0.004, 0.012], at: [0.05, 0.072, -1.8 + Float(index) * 0.6], colour: .stoneShade)
    }
    paths.attach(to: foreground, name: "garden-path-colours")
    return foreground
  }

  private static func makeForeground() -> Shapes {
    let shapes = Shapes()
    for side: Float in [-1, 1] {
      shapes.tree(at: [side * 1.91, 0.04, -0.95], height: side < 0 ? 0.87 : 0.72)
      shapes.facetedBlob([0.48, 0.24, 0.42], at: [side * 1.75, 0.15, 1.1], colour: .leavesLight)
      for index in 0..<3 {
        let x = side * (1.38 + Float(index) * 0.19)
        let z = 1.37 - Float(index) * 0.18
        shapes.cylinder(height: 0.19, bottom: 0.008, top: 0.006, at: [x, 0.14, z], colour: .leaves, sides: 4)
        shapes.facetedBlob([0.072, 0.032, 0.072], at: [x, 0.245, z], colour: index == 0 ? .flowerBlue : .stoneLight, sides: 5)
      }
    }
    // Edge foliage frames the view from inside the garden, leaving the bridge approach open.
    shapes.tree(at: [-2.2, 0.04, -0.7], height: 3.4)
    shapes.tree(at: [2.5, 0.04, -0.4], height: 2.7)
    shapes.facetedBlob([1.3, 0.5, 0.9], at: [-0.55, 0.28, 1.35], colour: .leaves)
    shapes.facetedBlob([1.2, 0.55, 0.9], at: [2.05, 0.30, 1.15], colour: .leavesLight)

    // A second small lookout and an open bridge establish scale below the citadel.
    shapes.rock(radius: 0.57, depth: 0.8, at: [0.05, 0.32, -4.6], colour: .rockLight, sides: 10)
    shapes.cylinder(height: 0.07, bottom: 0.57, top: 0.56, at: [0.05, 0.355, -4.6], colour: .grassLight, sides: 10)
    shapes.cylinder(height: 0.04, bottom: 0.32, top: 0.32, at: [0.05, 0.41, -4.52], colour: .stone, sides: 10)
    let bridgeStart = SIMD3<Float>(0.05, 0.07, -2.1)
    let bridgeEnd = SIMD3<Float>(0.05, 0.41, -4.24)
    shapes.beam(from: bridgeStart, to: bridgeEnd, width: 0.34, height: 0.07, colour: .stone)
    for side: Float in [-1, 1] {
      let offset = SIMD3<Float>(side * 0.15, 0.25, 0)
      shapes.beam(from: bridgeStart + offset, to: bridgeEnd + offset, width: 0.025, height: 0.025, colour: .stoneLight)
      for index in 0..<6 {
        let t = Float(index) / 5
        let position = simd_mix(bridgeStart, bridgeEnd, SIMD3<Float>(repeating: t))
        shapes.box([0.025, 0.25, 0.025], at: position + [side * 0.15, 0.125, 0], colour: .stone)
      }
      shapes.box([0.065, 0.42, 0.065], at: [0.05 + side * 0.24, 0.64, -4.86], colour: .stoneLight)
    }
    return shapes
  }

  private static func makeCitadel() -> Shapes {
    let shapes = Shapes()
    shapes.rock(radius: 3.1, depth: 2.4, at: [0, -0.04, 0], colour: .rock, sides: 24)
    shapes.cylinder(height: 0.2, bottom: 3.19, top: 3.2, at: [0, 0.02, 0], colour: .stoneShade, sides: 28)
    let radii: [Float] = [3.2, 2.8, 2.37, 1.93, 1.49, 1.06, 0.63]
    for (tier, radius) in radii.enumerated() {
      let floor = Float(tier) * 0.55 + 0.12
      shapes.cylinder(height: 0.41, bottom: radius, top: radius - 0.025, at: [0, floor + 0.205, 0], colour: .stone, sides: 28)
      shapes.cylinder(height: 0.035, bottom: radius + 0.016, top: radius + 0.016, at: [0, floor + 0.385, 0], colour: .stoneShade, sides: 28)
      shapes.cylinder(height: 0.055, bottom: radius + 0.058, top: radius + 0.058, at: [0, floor + 0.44, 0], colour: .stoneLight, sides: 28)
      shapes.cylinder(height: 0.065, bottom: radius - 0.005, top: radius - 0.005, at: [0, floor + 0.5, 0], colour: tier % 2 == 0 ? .grassLight : .grass, sides: 28)
      let openingCount = max(8, 22 - tier * 2)
      for opening in 0..<openingCount {
        let angle = Float(opening) / Float(openingCount) * 2 * .pi
        let distance = radius - 0.006
        shapes.box(
          [0.075, 0.17, 0.012],
          at: [sin(angle) * distance, floor + 0.22, cos(angle) * distance],
          colour: .recess, yaw: angle
        )
      }
      if tier == 0 || tier == 2 || tier == 4 {
        for (index, angle) in [Float(-1.43), -0.92, 0.87, 1.41].enumerated() {
          let x = sin(angle) * (radius - 0.16)
          let z = cos(angle) * (radius - 0.16)
          let height: Float = index % 2 == 0 ? 0.27 : 0.34
          shapes.box([0.23, height, 0.25], at: [x, floor + 0.54 + height / 2, z], colour: .stoneLight, yaw: angle)
          shapes.cylinder(height: 0.18, bottom: 0.19, top: 0, at: [x, floor + 0.63 + height, z], colour: .roof, sides: 4, yaw: angle + .pi / 4)
        }
      }
    }
    shapes.box([0.75, 0.66, 0.78], at: [0, 4.29, 0], colour: .stone)
    shapes.cylinder(height: 0.39, bottom: 0.61, top: 0, at: [0, 4.815, 0], colour: .roof, sides: 4, yaw: .pi / 4)
    shapes.turret(at: [-0.22, 3.96, 0.13], height: 1.12, radius: 0.17)
    shapes.turret(at: [0.32, 3.96, -0.17], height: 0.86, radius: 0.14)
    for side: Float in [-1, 1] {
      shapes.turret(at: [side * 2.63, 0.65, 0.75], height: 0.8, radius: 0.145)
      shapes.turret(at: [side * 1.35, 2.85, -0.05], height: 0.73, radius: 0.125)
    }
    return shapes
  }

  private enum Colour: UInt32, CaseIterable {
    case stone = 0xECE8DC
    case stoneLight = 0xFFF2D9
    case stoneShade = 0xB1C0C9
    case rock = 0x8B9DB2
    case rockLight = 0xA6B6C5
    case grass = 0x90B79B
    case grassLight = 0xB1C69B
    case leaves = 0x77AA97
    case leavesLight = 0xB0CBA3
    case trunk = 0x9DAA9C
    case roof = 0x7FA0AA
    case recess = 0x819DAC
    case water = 0x9AD2D7
    case waterLight = 0xD6F3EB
    case flowerBlue = 0xB2C0DE
    case cloud = 0xF3F3E9
    case cloudShade = 0xD1E3E7

    func material(haze: Float) -> SimpleMaterial {
      let hex = rawValue
      let base = SIMD3<Float>(Float((hex >> 16) & 255), Float((hex >> 8) & 255), Float(hex & 255)) / 255
      let tint = simd_mix(base, SIMD3<Float>(0.68, 0.84, 0.91), SIMD3<Float>(repeating: haze))
      let color = NSColor(
        srgbRed: CGFloat(tint.x),
        green: CGFloat(tint.y),
        blue: CGFloat(tint.z),
        alpha: 1
      )
      return SimpleMaterial(color: color, roughness: 1, isMetallic: false)
    }
  }

  /// Vertices are intentionally split for every triangle, including caps and box faces.
  private struct Triangles {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    mutating func append(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, outward: SIMD3<Float>) {
      var second = b
      var third = c
      var normal = simd_cross(second - a, third - a)
      guard simd_length_squared(normal) > 0.0000000001 else { return }
      if simd_dot(normal, outward) < 0 {
        swap(&second, &third)
        normal = -normal
      }
      normal = simd_normalize(normal)
      let first = UInt32(positions.count)
      positions.append(contentsOf: [a, second, third])
      normals.append(contentsOf: [normal, normal, normal])
      indices.append(contentsOf: [first, first + 1, first + 2])
    }
  }

  @MainActor
  private final class Shapes {
    private var batches: [Colour: Triangles] = [:]

    func attach(to parent: Entity, name: String, haze: Float = 0) {
      for colour in Colour.allCases {
        guard let triangles = batches[colour], !triangles.indices.isEmpty else { continue }
        var descriptor = MeshDescriptor(name: "\(name)-\(colour.rawValue)")
        descriptor.positions = MeshBuffer(triangles.positions)
        descriptor.normals = MeshBuffer(triangles.normals)
        descriptor.primitives = .triangles(triangles.indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { continue }
        let model = ModelEntity(mesh: mesh, materials: [colour.material(haze: haze)])
        model.name = "\(name)-\(colour.rawValue)"
        parent.addChild(model)
      }
    }

    private func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, normal: SIMD3<Float>, colour: Colour) {
      batches[colour, default: Triangles()].append(a, b, c, outward: normal)
    }

    private func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>, normal: SIMD3<Float>, colour: Colour) {
      triangle(a, b, c, normal: normal, colour: colour)
      triangle(a, c, d, normal: normal, colour: colour)
    }

    func box(_ size: SIMD3<Float>, at position: SIMD3<Float>, colour: Colour, yaw: Float = 0) {
      let half = size / 2
      let rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
      let faces: [(SIMD3<Float>, [SIMD3<Float>])] = [
        ([0, 0, 1], [[-half.x, -half.y, half.z], [half.x, -half.y, half.z], [half.x, half.y, half.z], [-half.x, half.y, half.z]]),
        ([0, 0, -1], [[half.x, -half.y, -half.z], [-half.x, -half.y, -half.z], [-half.x, half.y, -half.z], [half.x, half.y, -half.z]]),
        ([1, 0, 0], [[half.x, -half.y, half.z], [half.x, -half.y, -half.z], [half.x, half.y, -half.z], [half.x, half.y, half.z]]),
        ([-1, 0, 0], [[-half.x, -half.y, -half.z], [-half.x, -half.y, half.z], [-half.x, half.y, half.z], [-half.x, half.y, -half.z]]),
        ([0, 1, 0], [[-half.x, half.y, half.z], [half.x, half.y, half.z], [half.x, half.y, -half.z], [-half.x, half.y, -half.z]]),
        ([0, -1, 0], [[-half.x, -half.y, -half.z], [half.x, -half.y, -half.z], [half.x, -half.y, half.z], [-half.x, -half.y, half.z]]),
      ]
      for (normal, corners) in faces {
        let points = corners.map { position + rotation.act($0) }
        quad(points[0], points[1], points[2], points[3], normal: rotation.act(normal), colour: colour)
      }
    }

    func beam(from start: SIMD3<Float>, to end: SIMD3<Float>, width: Float, height: Float, colour: Colour) {
      let direction = simd_normalize(end - start)
      let right = simd_normalize(simd_cross(direction, [0, 1, 0])) * width / 2
      let up = simd_normalize(simd_cross(right, direction)) * height / 2
      let a = start - right - up
      let b = start + right - up
      let c = start + right + up
      let d = start - right + up
      let e = end - right - up
      let f = end + right - up
      let g = end + right + up
      let h = end - right + up
      quad(a, b, c, d, normal: -direction, colour: colour)
      quad(e, f, g, h, normal: direction, colour: colour)
      quad(d, c, g, h, normal: up, colour: colour)
      quad(a, b, f, e, normal: -up, colour: colour)
      quad(b, c, g, f, normal: right, colour: colour)
      quad(a, d, h, e, normal: -right, colour: colour)
    }

    func cylinder(height: Float, bottom: Float, top: Float, at position: SIMD3<Float>, colour: Colour, sides: Int = 10, yaw: Float = 0) {
      for side in 0..<sides {
        let a = Float(side) / Float(sides) * 2 * .pi + yaw
        let b = Float(side + 1) / Float(sides) * 2 * .pi + yaw
        let p0 = position + SIMD3<Float>(cos(a) * bottom, -height / 2, sin(a) * bottom)
        let p1 = position + SIMD3<Float>(cos(b) * bottom, -height / 2, sin(b) * bottom)
        let p2 = position + SIMD3<Float>(cos(b) * top, height / 2, sin(b) * top)
        let p3 = position + SIMD3<Float>(cos(a) * top, height / 2, sin(a) * top)
        let outward = SIMD3<Float>(cos((a + b) / 2), 0, sin((a + b) / 2))
        quad(p0, p1, p2, p3, normal: outward, colour: colour)
        triangle(position + [0, height / 2, 0], p3, p2, normal: [0, 1, 0], colour: colour)
        triangle(position - [0, height / 2, 0], p0, p1, normal: [0, -1, 0], colour: colour)
      }
    }

    func rock(radius: Float, depth: Float, at position: SIMD3<Float>, colour: Colour, sides: Int) {
      var rings: [[SIMD3<Float>]] = []
      for ring in 0..<3 {
        let scale: Float = [1, 0.72, 0.26][ring]
        let drop: Float = [0, 0.37, 0.79][ring]
        let vertices = (0..<sides).map { side -> SIMD3<Float> in
          let angle = Float(side) / Float(sides) * 2 * .pi
          let irregularity = 1 + sin(Float(side) * 2.41 + Float(ring) * 1.7) * 0.065
          let y = -depth * drop + (ring == 0 ? 0 : sin(Float(side) * 1.9 + Float(ring)) * depth * 0.035)
          return position + [cos(angle) * radius * scale * irregularity, y, sin(angle) * radius * scale * irregularity]
        }
        rings.append(vertices)
      }
      for ring in 0..<2 {
        for side in 0..<sides {
          let next = (side + 1) % sides
          let outward = (rings[ring][side] + rings[ring][next]) / 2 - position
          quad(rings[ring][side], rings[ring][next], rings[ring + 1][next], rings[ring + 1][side], normal: [outward.x, 0, outward.z], colour: colour)
        }
      }
      let tip = position + SIMD3<Float>(radius * 0.05, -depth, radius * -0.04)
      for side in 0..<sides {
        let next = (side + 1) % sides
        let outward = (rings[2][side] + rings[2][next]) / 2 - position
        triangle(rings[2][side], rings[2][next], tip, normal: [outward.x, 0, outward.z], colour: colour)
        triangle(position, rings[0][side], rings[0][next], normal: [0, 1, 0], colour: colour)
      }
    }

    func facetedBlob(_ size: SIMD3<Float>, at position: SIMD3<Float>, colour: Colour, sides: Int = 7) {
      var upper: [SIMD3<Float>] = []
      var lower: [SIMD3<Float>] = []
      for side in 0..<sides {
        let angle = Float(side) / Float(sides) * 2 * .pi
        upper.append(position + [cos(angle) * size.x * 0.36, size.y * 0.26, sin(angle) * size.z * 0.36])
        lower.append(position + [cos(angle) * size.x * 0.5, -size.y * 0.18, sin(angle) * size.z * 0.5])
      }
      for side in 0..<sides {
        let next = (side + 1) % sides
        let outward = (upper[side] + upper[next]) / 2 - position
        triangle(position + [0, size.y * 0.5, 0], upper[side], upper[next], normal: [outward.x, 1, outward.z], colour: colour)
        quad(upper[side], upper[next], lower[next], lower[side], normal: [outward.x, 0, outward.z], colour: colour)
        triangle(position - [0, size.y * 0.5, 0], lower[side], lower[next], normal: [outward.x, -1, outward.z], colour: colour)
      }
    }

    func tree(at position: SIMD3<Float>, height: Float) {
      cylinder(height: height * 0.62, bottom: height * 0.033, top: height * 0.019, at: position + [0, height * 0.31, 0], colour: .trunk, sides: 5)
      for side: Float in [-1, 1] {
        beam(from: position + [0, height * 0.42, 0], to: position + [side * height * 0.14, height * 0.64, 0], width: height * 0.025, height: height * 0.025, colour: .trunk)
      }
      facetedBlob([height * 0.52, height * 0.52, height * 0.49], at: position + [0, height * 0.74, 0], colour: .leaves)
      facetedBlob([height * 0.4, height * 0.37, height * 0.37], at: position + [-height * 0.13, height * 0.63, height * 0.015], colour: .leavesLight)
      facetedBlob([height * 0.35, height * 0.38, height * 0.34], at: position + [height * 0.15, height * 0.72, -height * 0.025], colour: .leaves)
    }

    func turret(at position: SIMD3<Float>, height: Float, radius: Float) {
      cylinder(height: height, bottom: radius, top: radius * 0.94, at: position + [0, height / 2, 0], colour: .stoneLight, sides: 8)
      cylinder(height: 0.045, bottom: radius * 1.13, top: radius * 1.13, at: position + [0, height - 0.03, 0], colour: .stoneShade, sides: 8)
      cylinder(height: height * 0.5, bottom: radius * 1.35, top: 0, at: position + [0, height * 1.25, 0], colour: .roof, sides: 8)
    }
  }
}
