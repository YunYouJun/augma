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
import { TransformNode } from '@babylonjs/core/Meshes/transformNode'
import { Scene } from '@babylonjs/core/scene'

/** All units are metres. The canal follows +Z; the railway converges along its east bank. */
export function createCityWorld(scene: Scene) {
  const skyColor = Color3.FromHexString('#bed7e4')
  scene.clearColor = new Color4(skyColor.r, skyColor.g, skyColor.b, 1)
  scene.fogMode = Scene.FOGMODE_LINEAR
  scene.fogColor = skyColor
  scene.fogStart = 105
  scene.fogEnd = 310
  scene.ambientColor = Color3.FromHexString('#cbd8e5').scale(0.08)

  const cameraOrigin = new Vector3(12, 11.5, -30)
  const cameraTarget = new Vector3(2.5, 13.4, 100)
  const camera = new FreeCamera('city-camera', cameraOrigin.clone(), scene)
  camera.fov = 0.86
  camera.minZ = 0.3
  camera.maxZ = 900
  camera.setTarget(cameraTarget)
  scene.activeCamera = camera

  const ambient = new HemisphericLight('city-sky-light', new Vector3(0, 1, 0), scene)
  ambient.intensity = 0.72
  ambient.diffuse = Color3.FromHexString('#e4edff')
  ambient.groundColor = Color3.FromHexString('#8b9fb7')
  const sunlight = new DirectionalLight('city-sunlight', new Vector3(0.6, -1, 0.35), scene)
  sunlight.diffuse = Color3.FromHexString('#fff0d9')
  sunlight.intensity = 0.62

  const batches = new Map<StandardMaterial, Mesh[]>()
  const material = (name: string, hex: string, emissive = 0) => {
    const result = new StandardMaterial(`city-${name}`, scene)
    result.diffuseColor = Color3.FromHexString(hex)
    result.specularColor = Color3.Black()
    result.emissiveColor = result.diffuseColor.scale(emissive)
    return result
  }
  const palette = {
    ivory: material('ivory', '#eee0cb'),
    pearl: material('pearl', '#dce6eb'),
    blue: material('blue-facades', '#8eb5d0'),
    dusk: material('distant-facades', '#8faac6'),
    glass: material('window-bands', '#597c97', 0.08),
    glassLight: material('pale-window-bands', '#83abbc', 0.12),
    paving: material('paving', '#cbd1cf'),
    pavingLight: material('paving-light', '#e2ded2'),
    rail: material('railway', '#c2d1dc'),
    underside: material('railway-underside', '#8298ab'),
    railMetal: material('rail-metal', '#697f96'),
    water: material('water', '#649bab', 0.03),
    reflection: material('water-reflections', '#a4c6ce', 0.14),
    green: material('foliage', '#75a397'),
    greenLight: material('sunlit-foliage', '#a1bba0'),
    trunk: material('tree-trunks', '#879b95'),
    accent: material('train-stripe', '#68a9b9', 0.1),
  }

  const add = (mesh: Mesh, surface: StandardMaterial, parent?: TransformNode) => {
    mesh.material = surface
    mesh.isPickable = false
    if (parent) {
      mesh.parent = parent
    }
    else {
      const group = batches.get(surface) ?? []
      group.push(mesh)
      batches.set(surface, group)
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
    sides = 8,
  ) => {
    const mesh = CreateCylinder(name, { height, diameterBottom: bottom, diameterTop: top, tessellation: sides }, scene)
    mesh.position.set(...position)
    mesh.convertToFlatShadedMesh()
    return add(mesh, surface)
  }

  // A vertex-coloured sky is geometry too: no downloaded textures or generated image layer.
  const sky = CreateSphere('city-sky', { diameter: 1400, segments: 16 }, scene)
  const skyMaterial = material('sky', '#ffffff', 1)
  skyMaterial.disableLighting = true
  skyMaterial.backFaceCulling = false
  sky.material = skyMaterial
  sky.isPickable = false
  sky.applyFog = false
  sky.infiniteDistance = true
  const skyPositions = sky.getVerticesData(VertexBuffer.PositionKind)!
  const skyColors: number[] = []
  const horizonColor = Color3.FromHexString('#f1d9ca')
  const zenithColor = Color3.FromHexString('#79b4e0')
  for (let index = 1; index < skyPositions.length; index += 3) {
    const height = Math.min(1, Math.max(0, skyPositions[index]! / 330))
    const color = Color3.Lerp(horizonColor, zenithColor, height)
    skyColors.push(color.r, color.g, color.b, 1)
  }
  sky.setVerticesData(VertexBuffer.ColorKind, skyColors)
  sky.freezeWorldMatrix()
  skyMaterial.freeze()

  // Long edges, paving seams and descending rail piers make the perspective legible.
  box('city-ground', [260, 1, 360], [0, -1.05, 125], palette.paving)
  box('city-canal', [17, 0.25, 330], [0, -0.45, 120], palette.water)
  for (const side of [-1, 1]) {
    box(`canal-wall-${side}`, [0.75, 1.3, 330], [side * 8.7, -0.1, 120], palette.ivory)
    box(`canal-cap-${side}`, [1.2, 0.18, 330], [side * 8.7, 0.64, 120], palette.pearl)
    box(`promenade-${side}`, [11.7, 0.55, 330], [side * 15.1, 0.02, 120], palette.pavingLight)
    box(`promenade-edge-${side}`, [0.28, 0.12, 330], [side * 20.6, 0.36, 120], palette.ivory)
    for (let z = -30; z < 250; z += 10) {
      box(`paving-seam-${side}-${z}`, [10.4, 0.022, 0.075], [side * 15.1, 0.308, z], palette.paving)
    }
    for (let z = -12; z < 160; z += 14) {
      box(`canal-post-${side}-${z}`, [0.12, 1, 0.12], [side * 8.7, 1.15, z], palette.underside)
    }
    box(`canal-handrail-${side}`, [0.11, 0.11, 188], [side * 8.7, 1.64, 72], palette.underside)
  }
  for (let index = 0; index < 18; index++) {
    const z = -10 + index * 12
    const width = 1.4 + (index % 4) * 0.72
    box(`water-light-${index}`, [width, 0.012, 0.11 + (index % 3) * 0.09], [Math.sin(index * 2.3) * 5.2, -0.313, z], palette.reflection)
  }

  const building = (index: number, x: number, z: number, width: number, depth: number, height: number, surface: StandardMaterial) => {
    box(`tower-${index}`, [width, height, depth], [x, height / 2 + 0.3, z], surface)
    // Broad, infrequent glazing bands keep the silhouette quiet at small viewport sizes.
    const bandHeight = height > 30 ? 1.7 : 1.15
    for (let y = 4.5; y < height - 3; y += 6.6) {
      box(`tower-front-${index}-${y}`, [width - 1.2, bandHeight, 0.07], [x, y, z - depth / 2 - 0.04], palette.glass)
      const inward = Math.sign(x) * -1
      box(`tower-side-${index}-${y}`, [0.07, bandHeight, depth - 1.4], [x + inward * (width / 2 + 0.04), y, z], palette.glassLight)
    }
    box(`tower-roof-${index}`, [width + 0.45, 0.4, depth + 0.45], [x, height + 0.44, z], palette.ivory)
    if (index % 3 === 0) {
      box(`tower-crown-${index}`, [width * 0.63, 4.5, depth * 0.65], [x, height + 2.75, z + depth * 0.08], surface)
      box(`tower-crown-cap-${index}`, [width * 0.63 + 0.3, 0.3, depth * 0.65 + 0.3], [x, height + 5.15, z + depth * 0.08], palette.ivory)
    }
    if (index % 4 === 1) {
      box(`tower-fin-${index}`, [0.5, height + 2.6, 1.6], [x - width * 0.24, height / 2 + 1.6, z - depth / 2 - 0.6], palette.ivory)
    }
  }
  const towers: [number, number, number, number, number, StandardMaterial][] = [
    [-33, 2, 15, 17, 37, palette.pearl],
    [-26, 31, 13, 16, 23, palette.ivory],
    [-39, 58, 19, 20, 43, palette.blue],
    [-25, 83, 12, 17, 28, palette.pearl],
    [-41, 108, 19, 19, 40, palette.ivory],
    [-25, 130, 11, 18, 21, palette.blue],
    [-48, 151, 24, 20, 48, palette.dusk],
    [39, 4, 17, 19, 40, palette.ivory],
    [31, 35, 13, 16, 27, palette.pearl],
    [48, 55, 19, 17, 49, palette.blue],
    [31, 75, 13, 14, 31, palette.ivory],
    [47, 97, 19, 20, 39, palette.pearl],
    [29, 119, 12, 19, 23, palette.ivory],
    [44, 143, 16, 21, 45, palette.blue],
    [-65, 31, 21, 21, 54, palette.dusk],
    [-63, 99, 20, 23, 59, palette.blue],
    [69, 18, 22, 24, 57, palette.pearl],
    [71, 84, 23, 22, 64, palette.dusk],
  ]
  towers.forEach(([x, z, width, depth, height, surface], index) => building(index, x, z, width, depth, height, surface))
  for (let index = 0; index < 11; index++) {
    const x = (index - 5) * 15
    if (Math.abs(x) < 15)
      continue
    building(index + 30, x, 198 + (index % 3) * 17, 11, 14, 22 + (index % 4) * 9, palette.dusk)
  }

  // A slender faceted landmark replaces dense science-fiction ornament.
  cylinder('landmark-base', 12, 19, 15, [-4, 6.3, 168], palette.pearl)
  cylinder('landmark-tower', 56, 12, 6.1, [-4, 40.3, 168], palette.ivory)
  cylinder('landmark-glass-belt', 4.6, 9.6, 9.1, [-4, 49.3, 168], palette.glassLight)
  cylinder('landmark-observation', 1.35, 13.7, 13.7, [-4, 52.3, 168], palette.pearl)
  cylinder('landmark-crown', 12, 6.5, 0.9, [-4, 74.3, 168], palette.pearl)
  cylinder('landmark-tip', 7, 0.65, 0.12, [-4, 83.7, 168], palette.ivory, 6)

  for (const side of [-1, 1]) {
    for (let index = 0; index < 11; index++) {
      const x = side * (18.6 + (index % 2) * 0.6)
      const z = -12 + index * 16
      box(`tree-planter-${side}-${index}`, [3.4, 0.55, 3.4], [x, 0.55, z], palette.pearl)
      cylinder(`tree-trunk-${side}-${index}`, 2.1, 0.28, 0.18, [x, 1.6, z], palette.trunk, 5)
      const canopy = CreateSphere(`tree-canopy-${side}-${index}`, { diameter: 4.2, segments: 2 }, scene)
      canopy.position.set(x, 3.8, z)
      canopy.scaling.set(1, 1.04 + (index % 3) * 0.1, 0.92)
      canopy.convertToFlatShadedMesh()
      add(canopy, index % 3 === 0 ? palette.greenLight : palette.green)
    }
  }

  // The rail line is a single straight incline in plan, so train/wheels never drift off it.
  const railSlope = -0.115
  const railX = (z: number) => 23 - z * 0.115
  const railAngle = Math.atan(railSlope)
  const railCenterZ = 84
  for (const [name, width, height, offset, surface] of [
    ['rail-deck', 4.5, 0.65, 8.05, palette.underside],
    ['rail-upper-deck', 4.8, 0.28, 8.5, palette.rail],
    ['rail-near-edge', 0.16, 0.43, 8.82, palette.ivory],
  ] as const) {
    const mesh = box(name, [width, height, 305], [railX(railCenterZ) + (name === 'rail-near-edge' ? -2.3 : 0), offset, railCenterZ], surface)
    mesh.rotation.y = railAngle
  }
  for (const offset of [-0.74, 0.74]) {
    const line = box(`train-track-${offset}`, [0.12, 0.1, 305], [railX(railCenterZ) + offset, 8.72, railCenterZ], palette.railMetal)
    line.rotation.y = railAngle
  }
  for (let z = -20; z < 230; z += 22) {
    box(`rail-pier-${z}`, [1.05, 7.6, 1.3], [railX(z), 4, z], palette.rail)
    const head = box(`rail-pier-head-${z}`, [4, 0.55, 1.5], [railX(z), 7.6, z], palette.rail)
    head.rotation.y = railAngle
  }

  for (const z of [69, 135]) {
    box(`footbridge-${z}`, [20.3, 0.5, 3.1], [0, 2.2, z], palette.pearl)
    box(`footbridge-front-${z}`, [20.3, 0.45, 0.12], [0, 3.05, z - 1.5], palette.rail)
    box(`footbridge-back-${z}`, [20.3, 0.45, 0.12], [0, 3.05, z + 1.5], palette.rail)
    for (const x of [-8.6, 8.6]) {
      box(`bridge-support-${z}-${x}`, [0.8, 3, 2.3], [x, 0.6, z], palette.underside)
    }
  }

  const train = new TransformNode('city-train', scene)
  for (let index = 0; index < 3; index++) {
    const z = index * -7.7
    box(`train-body-${index}`, [1.85, 1.25, 7.2], [0, 0.88, z], palette.pearl, train)
    box(`train-roof-${index}`, [1.65, 0.24, 6.6], [0, 1.61, z], palette.rail, train)
    box(`train-underbody-${index}`, [1.36, 0.25, 6.2], [0, 0.15, z], palette.railMetal, train)
    for (const side of [-1, 1]) {
      box(`train-windows-${index}-${side}`, [0.025, 0.46, 5.9], [side * 0.935, 1.14, z], palette.glass, train)
      box(`train-stripe-${index}-${side}`, [0.03, 0.12, 6.9], [side * 0.94, 0.6, z], palette.accent, train)
      for (let division = -2; division <= 2; division++) {
        box(`train-mullion-${index}-${side}-${division}`, [0.035, 0.48, 0.08], [side * 0.952, 1.14, z + division * 1.08], palette.pearl, train)
      }
    }
    box(`train-end-window-${index}`, [1.32, 0.52, 0.026], [0, 1.13, z - 3.62], palette.glass, train)
    box(`train-end-stripe-${index}`, [1.8, 0.13, 0.027], [0, 0.62, z - 3.63], palette.accent, train)
  }
  // Merge each material on the moving assembly separately from the static environment.
  const trainMeshes = train.getChildMeshes() as Mesh[]
  for (const surface of Object.values(palette)) {
    const matching = trainMeshes.filter(mesh => mesh.material === surface)
    if (matching.length < 2)
      continue
    const merged = Mesh.MergeMeshes(matching, true, true)
    if (merged) {
      merged.name = `train-${surface.name}`
      merged.parent = train
      merged.isPickable = false
    }
  }
  train.rotation.y = railAngle

  const windowLights: StandardMaterial[] = []
  for (let group = 0; group < 3; group++) {
    const light = material(`inhabited-windows-${group}`, '#e8d7ad', 0.35)
    windowLights.push(light)
    // Sparse lit rooms; continuous, slow brightness changes stay below a flash.
    const [towerX, towerZ, width, depth] = towers[group === 0 ? 8 : group === 1 ? 1 : 10]!
    for (let room = 0; room < 3; room++) {
      box(`lit-window-${group}-${room}`, [1.1, 1.02, 0.025], [towerX - width / 2 + 2.3 + room * 1.5, 11.1 + (room % 2) * 6.6, towerZ - depth / 2 - 0.086], light)
    }
  }

  // Static per-material batches keep this scenery inexpensive inside WKWebView.
  for (const [surface, meshes] of batches) {
    const merged = Mesh.MergeMeshes(meshes, true, true)
    if (merged) {
      merged.name = `city-static-${surface.name}`
      merged.isPickable = false
      merged.freezeWorldMatrix()
    }
    if (!windowLights.includes(surface))
      surface.freeze()
  }

  const update = (elapsedSeconds: number, depthX: number, depthY: number) => {
    // One pass takes 174 seconds. Both wrap points are behind the camera or beyond the fog.
    const z = ((elapsedSeconds * 1.65 + 104) % 287) - 62
    train.position.set(railX(z), 8.75, z)
    for (let index = 0; index < windowLights.length; index++) {
      const strength = 0.24 + (Math.sin(elapsedSeconds * (0.3 + index * 0.035) + index * 2.1) + 1) * 0.09
      windowLights[index]!.emissiveColor.copyFromFloats(strength, strength * 0.83, strength * 0.54)
    }
    camera.position.set(cameraOrigin.x + depthX * 0.6, cameraOrigin.y + depthY * 0.32, cameraOrigin.z)
    const aspect = scene.getEngine().getRenderWidth() / Math.max(1, scene.getEngine().getRenderHeight())
    camera.fov = aspect < 0.8 ? 1.04 : 0.86
    camera.setTarget(new Vector3(cameraTarget.x + depthX * 0.18, cameraTarget.y + depthY * 0.12, cameraTarget.z))
  }
  update(0, 0, 0)
  return { camera, update }
}
