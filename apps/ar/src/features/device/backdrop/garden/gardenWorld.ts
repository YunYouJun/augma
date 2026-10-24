import { VertexBuffer } from '@babylonjs/core/Buffers/buffer'
import { FreeCamera } from '@babylonjs/core/Cameras/freeCamera'
import { DirectionalLight } from '@babylonjs/core/Lights/directionalLight'
import { HemisphericLight } from '@babylonjs/core/Lights/hemisphericLight'
import { StandardMaterial } from '@babylonjs/core/Materials/standardMaterial'
import { Color3, Color4 } from '@babylonjs/core/Maths/math.color'
import { Vector3 } from '@babylonjs/core/Maths/math.vector'
import { CreateBox } from '@babylonjs/core/Meshes/Builders/boxBuilder'
import { CreateCylinder } from '@babylonjs/core/Meshes/Builders/cylinderBuilder'
import { CreateSphere } from '@babylonjs/core/Meshes/Builders/sphereBuilder'
import { Mesh } from '@babylonjs/core/Meshes/mesh'
import { VertexData } from '@babylonjs/core/Meshes/mesh.vertexData'
import { TransformNode } from '@babylonjs/core/Meshes/transformNode'
import { Scene } from '@babylonjs/core/scene'

/** A garden balcony faces a terraced citadel, with open air beneath every island. */
export function createGardenWorld(scene: Scene) {
  const skyColor = Color3.FromHexString('#d5e8ec')
  scene.clearColor = new Color4(skyColor.r, skyColor.g, skyColor.b, 1)
  scene.fogMode = Scene.FOGMODE_LINEAR
  scene.fogColor = skyColor
  scene.fogStart = 150
  scene.fogEnd = 420
  scene.ambientColor = Color3.FromHexString('#a9b9d5').scale(0.07)

  // Stay within the garden canopy instead of viewing the foreground as a whole island.
  const cameraOrigin = new Vector3(0, 7.3, -20.5)
  const cameraTarget = new Vector3(0, 27.3, 140)
  const camera = new FreeCamera('garden-camera', cameraOrigin.clone(), scene)
  camera.fov = 0.91
  camera.minZ = 0.3
  camera.maxZ = 850
  camera.setTarget(cameraTarget)
  scene.activeCamera = camera

  const ambient = new HemisphericLight('garden-sky-light', new Vector3(0, 1, 0), scene)
  ambient.intensity = 0.75
  ambient.diffuse = Color3.FromHexString('#e9efff')
  ambient.groundColor = Color3.FromHexString('#8b8fab')
  const sunlight = new DirectionalLight('garden-sunlight', new Vector3(0.7, -1, 0.35), scene)
  sunlight.diffuse = Color3.FromHexString('#fff2d8')
  sunlight.intensity = 0.67

  const batches = new Map<StandardMaterial, Mesh[]>()
  const material = (name: string, hex: string, emissive = 0) => {
    const result = new StandardMaterial(`garden-${name}`, scene)
    result.diffuseColor = Color3.FromHexString(hex)
    result.specularColor = Color3.Black()
    result.emissiveColor = result.diffuseColor.scale(emissive)
    return result
  }
  const palette = {
    stone: material('cream-stone', '#ece6d6'),
    stoneLight: material('sunlit-stone', '#fff2d8'),
    stoneShade: material('stone-shadow', '#aab8be'),
    rock: material('floating-rock', '#73859b'),
    rockLight: material('rock-ridges', '#8e9cab'),
    grass: material('garden-grass', '#80a78a'),
    grassLight: material('sunlit-grass', '#a1bb8d'),
    leaves: material('sage-foliage', '#689889'),
    leavesLight: material('sunlit-foliage', '#a3bf99'),
    trunk: material('tree-trunks', '#8d9a91'),
    roof: material('slate-roofs', '#78979b'),
    recess: material('castle-openings', '#7e98a7'),
    water: material('falling-water', '#8ec6ce', 0.08),
    waterLight: material('water-light', '#d6f0e9', 0.17),
    flower: material('white-flowers', '#fff4dc'),
    flowerBlue: material('blue-flowers', '#9badd0'),
    cloud: material('clouds', '#f4f1e7', 0.12),
    cloudShade: material('cloud-shadows', '#c3dce2', 0.09),
  }

  const add = (mesh: Mesh, surface: StandardMaterial, parent?: TransformNode) => {
    mesh.material = surface
    mesh.isPickable = false
    if (parent) {
      mesh.parent = parent
    }
    else {
      const meshes = batches.get(surface) ?? []
      meshes.push(mesh)
      batches.set(surface, meshes)
    }
    return mesh
  }
  const box = (
    name: string,
    dimensions: [number, number, number],
    position: [number, number, number],
    surface: StandardMaterial,
    parent?: TransformNode,
  ) => {
    const mesh = CreateBox(name, { width: dimensions[0], height: dimensions[1], depth: dimensions[2] }, scene)
    mesh.position.set(...position)
    return add(mesh, surface, parent)
  }
  const cylinder = (
    name: string,
    height: number,
    bottom: number,
    top: number,
    position: [number, number, number],
    surface: StandardMaterial,
    sides = 12,
    parent?: TransformNode,
  ) => {
    const mesh = CreateCylinder(name, { height, diameterBottom: bottom, diameterTop: top, tessellation: sides }, scene)
    mesh.position.set(...position)
    mesh.convertToFlatShadedMesh()
    return add(mesh, surface, parent)
  }
  const facets = (
    name: string,
    dimensions: [number, number, number],
    position: [number, number, number],
    surface: StandardMaterial,
    parent?: TransformNode,
  ) => {
    const mesh = CreateSphere(name, { diameter: 1, segments: 2 }, scene)
    mesh.scaling.set(...dimensions)
    mesh.position.set(...position)
    mesh.convertToFlatShadedMesh()
    return add(mesh, surface, parent)
  }
  const mergeAssembly = (node: TransformNode) => {
    const children = node.getChildMeshes() as Mesh[]
    for (const surface of Object.values(palette)) {
      const matching = children.filter(mesh => mesh.material === surface)
      if (matching.length < 2)
        continue
      const merged = Mesh.MergeMeshes(matching, true, true)
      if (merged) {
        merged.name = `${node.name}-${surface.name}`
        merged.parent = node
        merged.isPickable = false
      }
    }
  }

  // Uneven rings form a pointed underside; each triangle keeps its own flat normal.
  const floatingRock = (
    name: string,
    radius: number,
    depth: number,
    position: [number, number, number],
    surface: StandardMaterial,
    parent?: TransformNode,
    sides = 14,
  ) => {
    const positions: number[] = []
    const indices: number[] = []
    for (let ring = 0; ring < 3; ring++) {
      const scale = [1, 0.72, 0.26][ring]!
      const drop = [0, 0.37, 0.79][ring]!
      for (let index = 0; index < sides; index++) {
        const angle = index / sides * Math.PI * 2
        const irregularity = 1 + Math.sin(index * 2.41 + ring * 1.7) * 0.08
        positions.push(
          Math.cos(angle) * radius * scale * irregularity,
          -depth * drop + (ring ? Math.sin(index * 1.9 + ring) * depth * 0.035 : 0),
          Math.sin(angle) * radius * scale * irregularity,
        )
      }
    }
    positions.push(radius * 0.05, -depth, radius * -0.04)
    const tip = sides * 3
    for (let ring = 0; ring < 2; ring++) {
      for (let index = 0; index < sides; index++) {
        const next = (index + 1) % sides
        const a = ring * sides + index
        const b = ring * sides + next
        const c = (ring + 1) * sides + index
        const d = (ring + 1) * sides + next
        indices.push(a, c, b, b, c, d)
      }
    }
    for (let index = 0; index < sides; index++) {
      indices.push(sides * 2 + index, tip, sides * 2 + (index + 1) % sides)
    }
    const normals: number[] = []
    VertexData.ComputeNormals(positions, indices, normals)
    const data = new VertexData()
    data.positions = positions
    data.indices = indices
    data.normals = normals
    const mesh = new Mesh(name, scene)
    data.applyToMesh(mesh)
    mesh.convertToFlatShadedMesh()
    mesh.position.set(...position)
    return add(mesh, surface, parent)
  }
  const tree = (name: string, x: number, y: number, z: number, size: number, parent?: TransformNode) => {
    cylinder(`${name}-trunk`, size * 0.67, size * 0.055, size * 0.035, [x, y + size * 0.335, z], palette.trunk, 5, parent)
    for (const side of [-1, 1]) {
      const branch = cylinder(`${name}-branch-${side}`, size * 0.3, size * 0.035, size * 0.018, [x + side * size * 0.065, y + size * 0.52, z], palette.trunk, 5, parent)
      branch.rotation.z = side * -0.45
    }
    facets(`${name}-crown`, [size * 0.64, size * 0.62, size * 0.57], [x, y + size * 0.82, z], palette.leaves, parent)
    facets(`${name}-crown-left`, [size * 0.46, size * 0.44, size * 0.46], [x - size * 0.24, y + size * 0.7, z - size * 0.02], palette.leavesLight, parent)
    facets(`${name}-crown-right`, [size * 0.39, size * 0.41, size * 0.41], [x + size * 0.24, y + size * 0.79, z + size * 0.05], palette.leaves, parent)
  }

  // The sky gradient is vertex colour on a sphere, with no image or screen-space effect.
  const sky = CreateSphere('garden-sky', { diameter: 1400, segments: 16 }, scene)
  const skyMaterial = material('sky', '#ffffff', 1)
  skyMaterial.disableLighting = true
  skyMaterial.backFaceCulling = false
  sky.material = skyMaterial
  sky.isPickable = false
  sky.applyFog = false
  sky.infiniteDistance = true
  const skyPositions = sky.getVerticesData(VertexBuffer.PositionKind)!
  const skyColors: number[] = []
  const horizonColor = Color3.FromHexString('#e8eddf')
  const zenithColor = Color3.FromHexString('#69acd3')
  for (let index = 1; index < skyPositions.length; index += 3) {
    const height = Math.min(1, Math.max(0, skyPositions[index]! / 430))
    const color = Color3.Lerp(horizonColor, zenithColor, height)
    skyColors.push(color.r, color.g, color.b, 1)
  }
  sky.setVerticesData(VertexBuffer.ColorKind, skyColors)
  sky.freezeWorldMatrix()
  skyMaterial.freeze()

  // A wide garden at human scale gives the distant castle its monumental scale.
  const gardenBase = floatingRock('garden-main-island', 29, 19, [0, -1, 4], palette.rock, undefined, 18)
  gardenBase.scaling.z = 1.2
  const gardenGrass = cylinder('garden-lawn', 1.2, 59, 58, [0, -0.35, 4], palette.grass, 18)
  gardenGrass.scaling.z = 1.2
  box('garden-main-path', [9.8, 0.28, 57], [0, 0.36, 2], palette.stone)
  for (const side of [-1, 1]) {
    box(`garden-path-border-${side}`, [0.4, 0.35, 56], [side * 5.05, 0.4, 2], palette.stoneLight)
    for (let z = -18; z <= 25; z += 7) {
      box(`garden-path-seam-${side}-${z}`, [4.7, 0.012, 0.065], [side * 2.45, 0.506, z], palette.stoneShade)
    }
    box(`garden-overlook-post-${side}`, [0.8, 1.7, 0.8], [side * 6.9, 1.25, 29], palette.stone)
    box(`garden-overlook-cap-${side}`, [1.05, 0.25, 1.05], [side * 6.9, 2.22, 29], palette.stoneLight)
    box(`garden-overlook-rail-${side}`, [5.2, 0.28, 0.4], [side * 9.1, 1.78, 28.2], palette.stoneLight)
    for (let index = 0; index < 3; index++) {
      box(`garden-overlook-baluster-${side}-${index}`, [0.28, 1.2, 0.3], [side * (7.7 + index * 1.6), 1.05, 28.2], palette.stone)
    }
  }
  const overlook = cylinder('garden-overlook', 0.55, 26, 26, [0, 0.15, 25], palette.stone, 16)
  overlook.scaling.z = 0.75
  tree('garden-tree-near-left', -13, 0.3, 0, 11.5)
  tree('garden-tree-near-right', 15, 0.3, 7, 12)
  tree('garden-tree-far-left', -20, 0.3, 19, 9)
  tree('garden-tree-far-right', 20, 0.3, 23, 8)
  for (let index = 0; index < 12; index++) {
    const side = index % 2 ? -1 : 1
    const x = side * (7.2 + (index % 3) * 2.2)
    const z = -9 + Math.floor(index / 2) * 5.4
    facets(`garden-low-shrub-${index}`, [2.6, 1.15, 2.3], [x, 0.72, z], index % 3 ? palette.leaves : palette.grassLight)
    for (let flower = 0; flower < 3; flower++) {
      const flowerX = x + Math.sin(flower * 2.3 + index) * 1.5
      const flowerZ = z + Math.cos(flower * 1.7 + index) * 1.25
      cylinder(`garden-flower-stem-${index}-${flower}`, 0.65, 0.04, 0.04, [flowerX, 0.65, flowerZ], palette.leaves, 4)
      facets(`garden-flower-${index}-${flower}`, [0.42, 0.18, 0.42], [flowerX, 1, flowerZ], index % 3 ? palette.flower : palette.flowerBlue)
    }
  }

  // A narrow rising stone bridge leads to a second lookout, then stops at open sky.
  const bridgeStart = new Vector3(0, 0.45, 32)
  const bridgeEnd = new Vector3(0, 4.2, 64)
  const bridgeLength = Vector3.Distance(bridgeStart, bridgeEnd)
  const bridgeAngle = -Math.atan2(bridgeEnd.y - bridgeStart.y, bridgeEnd.z - bridgeStart.z)
  const bridge = box('garden-bridge', [4.1, 0.5, bridgeLength], [0, 2.325, 48], palette.stone)
  bridge.rotation.x = bridgeAngle
  for (const side of [-1, 1]) {
    const rail = box(`garden-bridge-rail-${side}`, [0.17, 0.17, bridgeLength], [side * 1.9, 3.65, 48], palette.stoneLight)
    rail.rotation.x = bridgeAngle
    for (let index = 0; index <= 8; index++) {
      box(`garden-bridge-post-${side}-${index}`, [0.2, 1.35, 0.2], [side * 1.9, 1.15 + index * 0.46875, 32 + index * 4], palette.stone)
    }
  }
  floatingRock('garden-lookout-rock', 9.1, 13, [0, 3.6, 68], palette.rockLight)
  cylinder('garden-lookout-lawn', 0.9, 18, 17.8, [0, 3.85, 68], palette.grassLight)
  cylinder('garden-lookout-paving', 0.25, 10, 10, [0, 4.43, 67], palette.stone, 12)
  tree('garden-lookout-tree', 5.1, 4.3, 70, 8)
  for (const side of [-1, 1]) {
    box(`garden-lookout-column-${side}`, [0.8, 3.9, 0.8], [side * 3.4, 6.5, 72], palette.stone)
    box(`garden-lookout-crown-${side}`, [1.25, 0.35, 1.25], [side * 3.4, 8.6, 72], palette.stoneLight)
  }

  // Broad stepped rings and the long hanging cone carry the floating-castle silhouette.
  const castleZ = 154
  const castleBase = 48
  floatingRock('garden-citadel-keel', 33.3, 30, [0, castleBase - 0.8, castleZ], palette.rock, undefined, 24)
  cylinder('garden-citadel-foundation', 2.5, 68.5, 69, [0, castleBase, castleZ], palette.stoneShade, 32)
  const castleRadii = [34, 30, 25.5, 21, 16.5, 12, 7.5]
  for (const [tier, radius] of castleRadii.entries()) {
    const floor = castleBase + 1.3 + tier * 4.6
    cylinder(`garden-castle-tier-${tier}`, 3.8, radius * 2, radius * 2 - 0.65, [0, floor + 1.9, castleZ], palette.stone, 32)
    cylinder(`garden-castle-shadow-band-${tier}`, 0.32, radius * 2 + 0.2, radius * 2 + 0.2, [0, floor + 3.55, castleZ], palette.stoneShade, 32)
    cylinder(`garden-castle-terrace-${tier}`, 0.42, radius * 2 + 1.35, radius * 2 + 1.35, [0, floor + 3.96, castleZ], palette.stoneLight, 32)
    cylinder(`garden-castle-roof-garden-${tier}`, 0.48, radius * 2 - 0.1, radius * 2 - 0.1, [0, floor + 4.38, castleZ], tier % 2 ? palette.grass : palette.grassLight, 32)
    const openings = Math.max(8, 24 - tier * 2)
    for (let index = 0; index < openings; index++) {
      const angle = index / openings * Math.PI * 2
      const opening = box(`garden-castle-window-${tier}-${index}`, [0.85, 1.8, 0.12], [Math.sin(angle) * (radius - 0.07), floor + 2, castleZ + Math.cos(angle) * (radius - 0.07)], palette.recess)
      opening.rotation.y = angle
    }
    // A few terrace houses break the perfect cone without covering it in tiny detail.
    if (tier === 0 || tier === 2 || tier === 4) {
      const houseAngles = tier === 2 ? [-1.22, -0.62, 0.8, 1.38] : [-1.4, -0.92, 1.02, 1.48]
      for (const [index, angle] of houseAngles.entries()) {
        const x = Math.sin(angle) * (radius - 1.65)
        const z = castleZ - Math.cos(angle) * (radius - 1.65)
        const height = 2.8 + (index % 2) * 1.1
        const house = box(`garden-castle-house-${tier}-${index}`, [2.35, height, 2.5], [x, floor + 4.65 + height / 2, z], palette.stoneLight)
        house.rotation.y = -angle
        const roof = cylinder(`garden-castle-house-roof-${tier}-${index}`, 1.7, 3.9, 0, [x, floor + 4.65 + height + 0.85, z], palette.roof, 4)
        roof.rotation.y = Math.PI / 4 - angle
        roof.scaling.z = 1.1
      }
    }
  }

  const turret = (name: string, x: number, baseY: number, z: number, height: number, radius: number) => {
    cylinder(`${name}-shaft`, height, radius * 2, radius * 1.85, [x, baseY + height / 2, z], palette.stoneLight, 8)
    cylinder(`${name}-belt`, 0.4, radius * 2.35, radius * 2.35, [x, baseY + height - 0.4, z], palette.stoneShade, 8)
    cylinder(`${name}-roof`, height * 0.48, radius * 2.7, 0.08, [x, baseY + height * 1.24, z], palette.roof, 8)
  }
  box('garden-citadel-palace', [8.2, 7.5, 8.7], [0, 85.2, castleZ], palette.stone)
  cylinder('garden-citadel-palace-roof', 4.3, 12, 0, [0, 91.1, castleZ], palette.roof, 4).rotation.y = Math.PI / 4
  turret('garden-citadel-spire', -2.4, 81.5, castleZ - 1.5, 16, 1.9)
  turret('garden-citadel-side-spire', 3.6, 81.5, castleZ + 2, 11.8, 1.55)
  for (const side of [-1, 1]) {
    turret(`garden-citadel-lower-turret-${side}`, side * 28.2, 54, castleZ - 8, 8.6, 1.65)
    turret(`garden-citadel-upper-turret-${side}`, side * 15.1, 72.1, castleZ + 1, 8.4, 1.4)
  }

  const floatingIslands: TransformNode[] = []
  const islandSites = [
    [-28, 17, 82, 8, 12],
    [29, 22, 104, 10, 15],
    [-54, 34, 157, 10, 17],
    [54, 42, 190, 12, 20],
  ] as const
  for (const [index, [x, y, z, radius, depth]] of islandSites.entries()) {
    const island = index < 2 ? new TransformNode(`garden-floating-island-${index}`, scene) : undefined
    floatingRock(`garden-island-rock-${index}`, radius, depth, [x, y, z], index % 2 ? palette.rock : palette.rockLight, island)
    cylinder(`garden-island-grass-${index}`, 0.75, radius * 1.97, radius * 1.92, [x, y + 0.24, z], palette.grassLight, 14, island)
    tree(`garden-island-tree-${index}`, x - radius * 0.18, y + 0.65, z, radius * 0.94, island)
    if (index === 1 || index === 2) {
      const fallX = x - radius * 0.25
      const fallZ = z - radius * 0.95
      box(`garden-waterfall-${index}`, [0.9, depth * 1.9, 0.13], [fallX, y - depth * 0.95, fallZ], palette.water, island)
      box(`garden-waterfall-light-${index}`, [0.22, depth * 1.7, 0.15], [fallX - 0.16, y - depth * 0.87, fallZ - 0.02], palette.waterLight, island)
    }
    if (island) {
      mergeAssembly(island)
      floatingIslands.push(island)
    }
  }

  // Three large, softly faceted cloud banks drift at different speeds below the islands.
  const clouds: TransformNode[] = []
  const cloudSites = [
    [-83, -10, 165, 39],
    [73, -4, 190, 43],
    [-25, -6, 240, 50],
  ] as const
  for (const [index, [x, y, z, size]] of cloudSites.entries()) {
    const cloud = new TransformNode(`garden-cloud-bank-${index}`, scene)
    for (let lobe = 0; lobe < 5; lobe++) {
      const offset = lobe - 2
      facets(`garden-cloud-${index}-${lobe}`, [size * (0.82 + (lobe % 2) * 0.16), size * (0.32 + (lobe % 3) * 0.07), size * 0.65], [x + offset * size * 0.3, y + Math.sin(lobe * 1.8) * size * 0.055, z + Math.cos(lobe * 2) * size * 0.1], lobe % 3 ? palette.cloud : palette.cloudShade, cloud)
    }
    mergeAssembly(cloud)
    clouds.push(cloud)
  }

  for (const [surface, meshes] of batches) {
    const merged = Mesh.MergeMeshes(meshes, true, true)
    if (merged) {
      merged.name = `garden-static-${surface.name}`
      merged.isPickable = false
      merged.freezeWorldMatrix()
    }
  }
  for (const surface of Object.values(palette)) {
    if (surface !== palette.waterLight)
      surface.freeze()
  }

  const update = (elapsedSeconds: number, depthX: number, depthY: number) => {
    for (const [index, island] of floatingIslands.entries()) {
      island.position.y = Math.sin(elapsedSeconds * (0.13 + index * 0.013) + index * 1.4) * 0.22
    }
    for (const [index, cloud] of clouds.entries()) {
      cloud.position.x = Math.sin(elapsedSeconds * (0.021 + index * 0.003) + index * 2.4) * 8
      cloud.position.z = Math.cos(elapsedSeconds * 0.018 + index) * 1.8
    }
    const waterStrength = 0.12 + (Math.sin(elapsedSeconds * 0.63) + 1) * 0.045
    palette.waterLight.emissiveColor.copyFromFloats(waterStrength * 0.84, waterStrength, waterStrength * 0.98)
    const aspect = scene.getEngine().getRenderWidth() / Math.max(1, scene.getEngine().getRenderHeight())
    camera.fov = aspect < 0.8 ? 1.08 : 0.91
    camera.position.set(cameraOrigin.x + depthX * 0.85, cameraOrigin.y + depthY * 0.4, cameraOrigin.z)
    camera.setTarget(new Vector3(cameraTarget.x + depthX * 0.12, cameraTarget.y + depthY * 0.1, cameraTarget.z))
  }
  update(0, 0, 0)
  return { camera, update }
}
