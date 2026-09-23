import { FreeCamera } from '@babylonjs/core/Cameras/freeCamera'
import { Engine } from '@babylonjs/core/Engines/engine'
import { HemisphericLight } from '@babylonjs/core/Lights/hemisphericLight'
import { StandardMaterial } from '@babylonjs/core/Materials/standardMaterial'
import { Color3, Color4 } from '@babylonjs/core/Maths/math.color'
import { Vector3 } from '@babylonjs/core/Maths/math.vector'
import { CreateTorus } from '@babylonjs/core/Meshes/Builders/torusBuilder'
import { Scene } from '@babylonjs/core/scene'
import { WebXRDefaultExperience } from '@babylonjs/core/XR/webXRDefaultExperience'

export function createXrScene(canvas: HTMLCanvasElement) {
  const engine = new Engine(canvas, true)
  const scene = new Scene(engine)
  scene.clearColor = new Color4(0, 0, 0, 0)
  const camera = new FreeCamera('camera', new Vector3(0, 1.5, 0), scene)
  camera.setTarget(new Vector3(0, 1.5, -2))
  const light = new HemisphericLight('light', new Vector3(0, 1, 0), scene)
  light.intensity = 0.8
  const marker = CreateTorus(
    'augma-marker',
    { diameter: 0.3, thickness: 0.015 },
    scene,
  )
  marker.position = new Vector3(0, 1.4, -1.2)
  const material = new StandardMaterial('accent', scene)
  material.emissiveColor = new Color3(0.85, 0.43, 0.08)
  marker.material = material
  return { engine, scene }
}

export const createExperience = (scene: Scene) =>
  WebXRDefaultExperience.CreateAsync(scene, {
    disableDefaultUI: true,
    disableTeleportation: true,
    disableNearInteraction: true,
  })
