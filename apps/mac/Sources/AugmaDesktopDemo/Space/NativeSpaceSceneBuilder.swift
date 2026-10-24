import AppKit
import RealityKit
import simd

/// Deterministic scenery with shared meshes and materials. Ambient movement uses
/// RealityKit animations, without frame subscriptions or downloaded assets.
@MainActor
final class NativeSpaceSceneBuilder {
  struct Marker {
    let root: Entity
    let badge: Entity
    let plate: ModelEntity
    let text: ModelEntity
    let selection: ModelEntity
    let pin: ModelEntity
    let position: SIMD3<Float>
  }

  let anchor = AnchorEntity(world: .zero)
  let world = Entity()
  let decoration = Entity()
  let markersRoot = Entity()
  let scanRoot = Entity()
  let scanSweep = Entity()
  let scanRadius = Entity()
  let routeRoot = Entity()
  let camera = PerspectiveCamera()
  let keyLight = DirectionalLight()
  let fillLight = DirectionalLight()
  private(set) var markers: [String: Marker] = [:]
  private(set) var scanSegments: [ModelEntity] = []
  private var routeSegments: [ModelEntity] = []
  private var routeTraveler: ModelEntity?
  private var routeIdentity: String?
  private var markerStyle: String?
  private var mirrored = false
  private let sceneID: NativeSpaceSceneID
  private var floatingGarden: Entity?
  private var ambientAnimations: [AnimationPlaybackController] = []
  private var lastCamera: (yaw: Double, pitch: Double, scale: Double, parallax: SIMD2<Float>)?

  private let cube = MeshResource.generateBox(size: 1, cornerRadius: 0.025)
  private let sphere = MeshResource.generateSphere(radius: 0.5)
  private let cylinder = MeshResource.generateCylinder(height: 1, radius: 0.5)
  private let cone = MeshResource.generateCone(height: 1, radius: 0.5)
  private let ring: MeshResource
  private var materials: [String: any Material] = [:]

  init(scene: NativeSpaceScene) {
    sceneID = scene.id
    ring = Self.makeRing()
    prepareMaterials()
    anchor.addChild(world)
    anchor.addChild(camera)
    anchor.addChild(keyLight)
    anchor.addChild(fillLight)
    world.addChild(decoration)
    // Mirror geometry, then place readable badges at the mirrored coordinates.
    anchor.addChild(markersRoot)
    world.addChild(scanRoot)
    world.addChild(routeRoot)
    camera.camera = PerspectiveCameraComponent(near: 0.05, far: 80, fieldOfViewInDegrees: scene.id == .garden ? 60 : 43)
    keyLight.light.intensity = 3_000
    keyLight.shadow = DirectionalLightComponent.Shadow()
    keyLight.look(at: .zero, from: [-3, 7, 4], relativeTo: nil)
    fillLight.light.intensity = 1_300
    fillLight.look(at: .zero, from: [4, 3, -4], relativeTo: nil)

    switch scene.id {
    case .garden: buildGarden(scene: scene)
    case .city: buildCity(scene: scene)
    case .workspace, .projects: break // Rendered by their dedicated workspace views.
    }
    buildMarkers(scene: scene)
    buildScan()
    buildRoute()
  }

  func update(
    selectedID: String,
    pinnedID: String?,
    scanning: Bool,
    progress: Double,
    routeStep: Int?,
    preferences: NativeScenePreferences
  ) {
    if mirrored != preferences.mirror {
      mirrored = preferences.mirror
      lastCamera = nil
    }
    world.scale = [preferences.mirror ? -1 : 1, 1, 1]
    decoration.isEnabled = preferences.sceneBackdrop && !preferences.focus
    markersRoot.isEnabled = preferences.showHud
    let style = "\(selectedID):\(pinnedID ?? "")"
    let styleChanged = markerStyle != style
    markerStyle = style
    for (id, marker) in markers {
      marker.root.position = [preferences.mirror ? -marker.position.x : marker.position.x, marker.position.y, marker.position.z]
      marker.root.isEnabled = !preferences.focus || id == selectedID || id == pinnedID
      marker.selection.isEnabled = id == selectedID
      marker.pin.isEnabled = id == pinnedID
      marker.badge.scale = SIMD3<Float>(repeating: id == selectedID ? 1.12 : 0.88)
      if styleChanged {
        marker.plate.model?.materials = [material(id == pinnedID ? "pin" : id == selectedID ? "teal" : "ink")]
        marker.text.model?.materials = [material(id == pinnedID || id == selectedID ? "ink" : "white")]
      }
    }
    scanRoot.isEnabled = scanning && preferences.showHud
    routeRoot.isEnabled = routeStep != nil && preferences.showHud
    if let routeStep, let target = markers[selectedID]?.position {
      updateRoute(target: target, step: routeStep, id: selectedID)
    }
    let fraction = Float(min(100, max(0, progress)) / 100)
    scanRadius.scale = [max(0.03, fraction * 4.15), 1, max(0.03, fraction * 4.15)]
    scanSweep.orientation = simd_quatf(angle: -fraction * 2 * .pi, axis: [0, 1, 0])
    for (index, segment) in scanSegments.enumerated() {
      segment.isEnabled = Float(index) < fraction * Float(scanSegments.count)
    }
    keyLight.light.intensity = preferences.dark ? 2_000 : 3_000
    fillLight.light.intensity = preferences.dark ? 800 : 1_300
  }

  func setCamera(yaw: Double, pitch: Double, scale: Double, parallax: SIMD2<Float> = .zero) {
    if let lastCamera, lastCamera.yaw == yaw, lastCamera.pitch == pitch,
       lastCamera.scale == scale, lastCamera.parallax == parallax { return }
    lastCamera = (yaw, pitch, scale, parallax)
    let eye: SIMD3<Float>
    let target: SIMD3<Float>
    if sceneID == .garden {
      // Stand inside the lawn. Looking around keeps the viewer at walking height;
      // zoom is a short dolly that cannot cross the nearby tree or terrace.
      eye = [0.85, 1.5, 3.3 + 2 * (1 / Float(scale) - 1)]
      let azimuth = Float(yaw) + 0.0457 + parallax.x
      let elevation = min(0.30, max(-0.12, 0.0457 - (Float(pitch) + 0.15) * 0.32 - parallax.y))
      target = eye + SIMD3<Float>(
        -sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation)
      ) * 15.3
    } else {
      let azimuth = Float(yaw) + 0.48 + parallax.x
      let elevation = min(1.35, max(0.22, Float(pitch) + 0.85 + parallax.y))
      let radius = 6.6 / Float(scale)
      target = [0, 0.35, 0]
      eye = target + SIMD3<Float>(
        sin(azimuth) * cos(elevation) * radius,
        sin(elevation) * radius,
        cos(azimuth) * cos(elevation) * radius
      )
    }
    camera.look(at: target, from: eye, relativeTo: nil)
    for marker in markers.values {
      // The numbered flags face the viewer while stems and rings stay in world space.
      let location = marker.badge.position(relativeTo: nil)
      marker.badge.look(at: eye, from: location, relativeTo: nil, forward: .positiveZ)
    }
  }

  func setAmbientMotionEnabled(_ enabled: Bool) {
    guard let floatingGarden else { return }
    if enabled && ambientAnimations.isEmpty {
      for (index, entity) in floatingGarden.children.enumerated() {
        let cloud = entity.name.hasPrefix("clouds-")
        guard cloud || entity.name.hasPrefix("floating-island-") else { continue }
        let start = entity.transform
        var end = start
        end.translation += cloud ? [0.5, 0, 0] : [0, 0.10, 0]
        let definition = FromToByAnimation(
          from: start, to: end, duration: cloud ? 24 + Double(index) : 7 + Double(index),
          timing: .easeInOut, bindTarget: .transform, repeatMode: .autoReverse
        )
        if let animation = try? AnimationResource.generate(with: definition) {
          ambientAnimations.append(entity.playAnimation(animation))
        }
      }
    }
    for animation in ambientAnimations {
      if enabled { animation.resume() } else { animation.pause() }
    }
  }

  func stopAmbientMotion() {
    ambientAnimations.forEach { $0.stop() }
    ambientAnimations.removeAll()
  }

  private func prepareMaterials() {
    func matte(_ key: String, _ hex: UInt32, metallic: Bool = false) {
      materials[key] = SimpleMaterial(color: Self.color(hex), roughness: 0.75, isMetallic: metallic)
    }
    matte("stone", 0xDCE5DF)
    matte("edge", 0x617B75)
    matte("path", 0xF4E8CE)
    matte("wood", 0x947152)
    matte("trunk", 0x6D5747)
    matte("leaf", 0x5D9E78)
    matte("leafLight", 0x94C39B)
    matte("leafDark", 0x377A65)
    matte("soil", 0x49574B)
    matte("cityBase", 0x8DA4AF)
    matte("cityEdge", 0x385367)
    matte("road", 0x3D5362)
    matte("tower", 0x6E91A5)
    matte("towerLight", 0xB2C7CD)
    matte("ivory", 0xECE5D4)
    matte("gold", 0xD8B568, metallic: true)
    matte("teal", 0x49BDAF, metallic: true)
    materials["glass"] = SimpleMaterial(
      color: Self.color(0x8ED8CF).withAlphaComponent(0.34), roughness: 0.12, isMetallic: false
    )
    materials["water"] = SimpleMaterial(color: Self.color(0x5AB7B0), roughness: 0.12, isMetallic: true)
    materials["glow"] = UnlitMaterial(color: Self.color(0x7AE7D2))
    materials["pin"] = UnlitMaterial(color: Self.color(0xF2CA7C))
    materials["ink"] = UnlitMaterial(color: Self.color(0x173F40))
    materials["white"] = UnlitMaterial(color: Self.color(0xF3FFF9))
  }

  private func buildGarden(scene: NativeSpaceScene) {
    let garden = NativeFloatingGarden.make()
    if let ground = garden.findEntity(named: "foreground-island") {
      world.addChild(ground)
    }
    decoration.addChild(garden)
    floatingGarden = garden
    // Landmark approaches sit on the floating island; a narrow watercourse crosses behind them.
    box(world, [3.65, 0.018, 0.18], at: [0, 0.077, -1.24], material: "water")
    for x: Float in [-0.85, 0.85] {
      box(world, [0.45, 0.04, 0.35], at: [x, 0.09, -1.24], material: "wood")
    }

    let terrace = landmark(scene.landmarks[0])
    box(terrace, [1.18, 0.16, 0.92], at: [0, 0.13, 0], material: "path")
    box(terrace, [1.08, 0.035, 0.82], at: [0, 0.23, 0], material: "wood")
    for x: Float in [-0.5, -0.17, 0.17, 0.5] {
      box(terrace, [0.022, 0.28, 0.022], at: [x, 0.38, -0.37], material: "gold")
    }
    box(terrace, [1.04, 0.025, 0.025], at: [0, 0.52, -0.37], material: "gold")
    for index in 0..<3 {
      box(terrace, [0.60, 0.055, 0.12], at: [0, 0.06 + Float(index) * 0.04, 0.48 + Float(2 - index) * 0.11], material: "stone")
    }
    bench(terrace, at: [0.05, 0.26, -0.17])
    terrace.generateCollisionShapes(recursive: true)

    let pavilion = landmark(scene.landmarks[1])
    box(pavilion, [1.12, 0.10, 1.08], at: [0, 0.11, 0], material: "path")
    for x: Float in [-0.43, 0.43] {
      for z: Float in [-0.39, 0.39] {
        box(pavilion, [0.045, 0.74, 0.045], at: [x, 0.52, z], material: "gold")
      }
    }
    box(pavilion, [0.84, 0.62, 0.018], at: [0, 0.51, -0.39], material: "glass")
    box(pavilion, [0.018, 0.62, 0.78], at: [-0.43, 0.51, 0], material: "glass")
    box(pavilion, [1.08, 0.04, 0.99], at: [0, 0.91, 0], material: "glass")
    for index in 0..<7 {
      box(pavilion, [0.035, 0.045, 1.02], at: [-0.48 + Float(index) * 0.16, 0.94, 0], material: "wood")
    }
    bench(pavilion, at: [0.04, 0.18, -0.18])
    pavilion.generateCollisionShapes(recursive: true)

    let tree = landmark(scene.landmarks[2])
    disk(tree, [0.88, 0.10, 0.88], at: [0, 0.12, 0], material: "path")
    disk(tree, [0.69, 0.10, 0.69], at: [0, 0.15, 0], material: "soil")
    let canopy = NativeFloatingGarden.makeTree()
    canopy.position = [0, 0.19, 0]
    tree.addChild(canopy)
    tree.generateCollisionShapes(recursive: true)

    for x: Float in [-1.85, 1.85] {
      for z: Float in [-0.55, 0.4] {
        disk(decoration, [0.045, 0.37, 0.045], at: [x, 0.25, z], material: "gold")
        disk(decoration, [0.11, 0.035, 0.11], at: [x, 0.45, z], material: "white")
      }
    }
  }

  private func buildCity(scene: NativeSpaceScene) {
    box(world, [4.3, 0.20, 3.75], at: [0, -0.14, 0], material: "cityEdge")
    box(world, [4.22, 0.10, 3.67], at: [0, 0.01, 0], material: "cityBase")
    box(world, [4.02, 0.012, 0.48], at: [0, 0.069, 0.27], material: "road")
    box(world, [0.48, 0.012, 3.55], at: [-0.18, 0.069, 0], material: "road")
    for index in 0..<9 {
      box(world, [0.15, 0.009, 0.018], at: [-1.75 + Float(index) * 0.43, 0.082, 0.27], material: "pin")
    }
    for index in 0..<4 {
      box(world, [0.045, 0.01, 0.36], at: [0.22 + Float(index) * 0.085, 0.084, 0.27], material: "ivory")
    }

    let gallery = landmark(scene.landmarks[0])
    box(gallery, [1.18, 0.10, 0.95], at: [0, 0.12, 0], material: "ivory")
    box(gallery, [0.94, 0.55, 0.65], at: [0, 0.43, -0.06], material: "ivory")
    box(gallery, [1.04, 0.12, 0.74], at: [0.03, 0.77, -0.06], material: "towerLight")
    box(gallery, [0.86, 0.41, 0.025], at: [0, 0.44, 0.276], material: "glass")
    for x: Float in [-0.31, 0, 0.31] {
      box(gallery, [0.025, 0.44, 0.06], at: [x, 0.44, 0.31], material: "gold")
    }
    // A sculptural golden portal is visible from the approach road.
    box(gallery, [0.055, 0.33, 0.055], at: [0.48, 0.33, 0.36], material: "gold")
    box(gallery, [0.22, 0.055, 0.055], at: [0.4, 0.50, 0.36], material: "gold")
    gallery.generateCollisionShapes(recursive: true)

    let station = landmark(scene.landmarks[1])
    box(station, [1.12, 0.12, 0.82], at: [0, 0.12, 0], material: "ivory")
    box(station, [0.98, 0.43, 0.58], at: [0, 0.39, -0.03], material: "glass")
    box(station, [1.18, 0.09, 0.89], at: [0, 0.68, -0.06], material: "teal")
    for x: Float in [-0.46, 0.46] {
      box(station, [0.045, 0.51, 0.045], at: [x, 0.4, 0.27], material: "cityEdge")
    }
    box(station, [0.72, 0.05, 0.03], at: [0, 0.53, 0.282], material: "glow")
    for x: Float in [-0.36, 0.36] {
      box(station, [0.025, 0.012, 0.68], at: [x, 0.19, 0], material: "gold")
    }
    station.generateCollisionShapes(recursive: true)

    let square = landmark(scene.landmarks[2])
    disk(square, [1.12, 0.07, 0.92], at: [0, 0.12, 0], material: "ivory")
    disk(square, [0.68, 0.08, 0.68], at: [0, 0.18, 0], material: "cityEdge")
    disk(square, [0.59, 0.02, 0.59], at: [0, 0.23, 0], material: "water")
    let sculpture = box(square, [0.14, 0.55, 0.14], at: [0, 0.52, 0], material: "gold")
    sculpture.orientation = simd_quatf(angle: .pi / 5, axis: [0, 0, 1])
    square.generateCollisionShapes(recursive: true)

    // A stepped skyline surrounds the three destinations without hiding them.
    let towers: [(SIMD3<Float>, SIMD3<Float>)] = [
      ([-1.55, 0, -1.3], [0.53, 1.22, 0.55]),
      ([-0.77, 0, -1.37], [0.46, 1.65, 0.47]),
      ([0.03, 0, -1.45], [0.48, 1.03, 0.38]),
      ([0.73, 0, -1.46], [0.45, 1.42, 0.4]),
      ([1.68, 0, 1.05], [0.53, 0.82, 0.64]),
      ([-1.6, 0, 1.17], [0.58, 0.67, 0.61]),
    ]
    for (index, item) in towers.enumerated() {
      let (position, size) = item
      let baseY = 0.09 + size.y / 2
      box(decoration, size, at: position + [0, baseY, 0], material: index % 2 == 0 ? "tower" : "towerLight")
      box(decoration, [size.x + 0.06, 0.06, size.z + 0.06], at: position + [0, 0.10 + size.y, 0], material: "cityEdge")
      for floor in 0..<Int(size.y / 0.25) {
        box(decoration, [size.x * 0.78, 0.045, 0.012], at: position + [0, 0.28 + Float(floor) * 0.25, size.z / 2 + 0.008], material: floor % 2 == 0 ? "pin" : "glass")
      }
    }
    for x: Float in [-0.72, 0.79] {
      for z: Float in [0.95, 1.5] {
        treeModel(decoration, at: [x, 0.08, z], size: 0.38)
      }
    }
    for position: SIMD3<Float> in [[1.35, 0.08, 0.27], [-1.6, 0.08, 0.27]] {
      box(decoration, [0.29, 0.13, 0.14], at: position + [0, 0.07, 0], material: "teal")
      box(decoration, [0.14, 0.07, 0.13], at: position + [0, 0.17, 0], material: "glass")
    }
  }

  private func buildMarkers(scene: NativeSpaceScene) {
    let heights: [Float] = scene.id == .garden ? [0.72, 1.16, 1.72] : [1.05, 0.92, 0.95]
    for (index, landmark) in scene.landmarks.enumerated() {
      let root = Entity()
      root.name = "landmark:\(landmark.id)"
      root.position = landmark.position
      markersRoot.addChild(root)
      let selection = ModelEntity(mesh: ring, materials: [material("glow")])
      selection.position.y = 0.095
      selection.scale = [1.46, 0.7, 1.46]
      root.addChild(selection)
      let pin = ModelEntity(mesh: ring, materials: [material("pin")])
      pin.position.y = 0.105
      pin.scale = [1.7, 1.6, 1.7]
      root.addChild(pin)

      let height = heights[index]
      disk(root, [0.017, 0.22, 0.017], at: [0, height - 0.09, 0], material: "glow")
      let badge = Entity()
      badge.position = [0, height + 0.11, 0]
      root.addChild(badge)
      let plate = box(badge, [0.31, 0.23, 0.025], at: .zero, material: "ink")
      plate.generateCollisionShapes(recursive: false)
      let textMesh = MeshResource.generateText(
        String(format: "%02d", index + 1), extrusionDepth: 0.001,
        font: NSFont.monospacedDigitSystemFont(ofSize: 0.15, weight: .semibold),
        containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping
      )
      let text = ModelEntity(mesh: textMesh, materials: [material("white")])
      let bounds = text.visualBounds(relativeTo: text)
      text.position = [-bounds.center.x, -bounds.center.y, 0.018]
      badge.addChild(text)
      markers[landmark.id] = Marker(root: root, badge: badge, plate: plate, text: text, selection: selection, pin: pin, position: landmark.position)
    }
  }

  private func buildScan() {
    scanRoot.addChild(scanRadius)
    scanRoot.addChild(scanSweep)
    let pulse = ModelEntity(mesh: ring, materials: [material("glow")])
    pulse.position.y = 0.09
    scanRadius.addChild(pulse)
    box(scanSweep, [0.022, 0.012, 2.04], at: [0, 0.09, -1.02], material: "glow")
    for index in 0..<48 {
      let angle = Float(index) / 48 * 2 * .pi
      let segment = box(scanRoot, [0.10, 0.016, 0.025], at: [sin(angle) * 2.04, 0.09, -cos(angle) * 2.04], material: "glow")
      segment.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
      scanSegments.append(segment)
    }
  }

  private func buildRoute() {
    for _ in 0..<18 {
      let segment = box(routeRoot, [0.065, 0.015, 0.065], at: .zero, material: "pin")
      routeSegments.append(segment)
    }
    let traveler = ModelEntity(mesh: sphere, materials: [material("white")])
    traveler.scale = SIMD3<Float>(repeating: 0.09)
    routeRoot.addChild(traveler)
    routeTraveler = traveler
  }

  private func updateRoute(target: SIMD3<Float>, step: Int, id: String) {
    let identity = "\(id):\(step)"
    guard identity != routeIdentity else { return }
    routeIdentity = identity
    let start: SIMD3<Float> = [0.05, 0.10, 1.55]
    let finish = target + SIMD3<Float>(0, 0.10, 0)
    let points: [SIMD3<Float>] = abs(target.x) < 0.10
      ? [start, finish]
      : [start, [0.05, 0.10, 0.28], [target.x, 0.10, 0.28], finish]
    let lengths = zip(points, points.dropFirst()).map { simd_distance($0, $1) }
    let total = lengths.reduce(0, +)
    func location(_ fraction: Float) -> SIMD3<Float> {
      var remaining = fraction * total
      for index in lengths.indices {
        let length = lengths[index]
        if remaining <= length || index == lengths.count - 1 {
          return simd_mix(points[index], points[index + 1], SIMD3<Float>(repeating: length > 0 ? remaining / length : 0))
        }
        remaining -= length
      }
      return finish
    }
    let progress = Float(min(4, max(0, step))) / 4
    for (index, segment) in routeSegments.enumerated() {
      let fraction = Float(index + 1) / Float(routeSegments.count)
      segment.position = location(fraction)
      segment.model?.materials = [material(fraction <= progress ? "glow" : "pin")]
    }
    routeTraveler?.position = location(progress) + [0, 0.045, 0]
  }

  private func landmark(_ landmark: NativeSpaceLandmark) -> Entity {
    let entity = Entity()
    entity.name = "landmark:\(landmark.id)"
    entity.position = landmark.position
    world.addChild(entity)
    return entity
  }

  private func bench(_ parent: Entity, at position: SIMD3<Float>) {
    box(parent, [0.50, 0.06, 0.18], at: position + [0, 0.16, 0], material: "wood")
    box(parent, [0.50, 0.18, 0.04], at: position + [0, 0.27, -0.09], material: "wood")
    for x: Float in [-0.18, 0.18] {
      box(parent, [0.035, 0.13, 0.12], at: position + [x, 0.065, 0], material: "gold")
    }
  }

  private func treeModel(_ parent: Entity, at position: SIMD3<Float>, size: Float) {
    let tree = Entity()
    tree.position = position
    tree.scale = SIMD3<Float>(repeating: size)
    parent.addChild(tree)
    let trunk = ModelEntity(mesh: cone, materials: [material("trunk")])
    trunk.scale = [0.17, 0.88, 0.17]
    trunk.position.y = 0.44
    tree.addChild(trunk)
    for (index, point) in [SIMD3<Float>(0, 1.1, 0), [-0.24, 0.91, 0.03], [0.27, 0.95, 0.07], [0.02, 0.87, -0.24], [0.03, 0.89, 0.26]].enumerated() {
      let canopy = ModelEntity(mesh: sphere, materials: [material(index % 3 == 0 ? "leafLight" : index % 3 == 1 ? "leaf" : "leafDark")])
      canopy.scale = [0.72, 0.62, 0.68]
      canopy.position = point
      tree.addChild(canopy)
    }
  }

  @discardableResult
  private func box(_ parent: Entity, _ size: SIMD3<Float>, at position: SIMD3<Float>, material key: String) -> ModelEntity {
    let entity = ModelEntity(mesh: cube, materials: [material(key)])
    entity.scale = size
    entity.position = position
    parent.addChild(entity)
    return entity
  }

  @discardableResult
  private func disk(_ parent: Entity, _ size: SIMD3<Float>, at position: SIMD3<Float>, material key: String) -> ModelEntity {
    let entity = ModelEntity(mesh: cylinder, materials: [material(key)])
    entity.scale = size
    entity.position = position
    parent.addChild(entity)
    return entity
  }

  private func material(_ key: String) -> any Material {
    materials[key] ?? SimpleMaterial(color: .gray, isMetallic: false)
  }

  private static func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
  }

  private static func makeRing() -> MeshResource {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    let slices = 48
    let sides = 6
    for slice in 0...slices {
      let u = Float(slice) / Float(slices) * 2 * .pi
      for side in 0...sides {
        let v = Float(side) / Float(sides) * 2 * .pi
        let normal = SIMD3<Float>(cos(u) * cos(v), sin(v), sin(u) * cos(v))
        positions.append(SIMD3<Float>(cos(u) * 0.5, 0, sin(u) * 0.5) + normal * 0.015)
        normals.append(normal)
        if slice < slices, side < sides {
          let a = UInt32(slice * (sides + 1) + side)
          let b = a + UInt32(sides + 1)
          indices.append(contentsOf: [a, a + 1, b, a + 1, b + 1, b])
        }
      }
    }
    var descriptor = MeshDescriptor(name: "augma.landmark.ring")
    descriptor.positions = MeshBuffer(positions)
    descriptor.normals = MeshBuffer(normals)
    descriptor.primitives = .triangles(indices)
    return (try? MeshResource.generate(from: [descriptor])) ?? .generateCylinder(height: 0.01, radius: 0.5)
  }
}
