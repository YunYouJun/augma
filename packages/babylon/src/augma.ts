/* eslint-disable no-new */
import { ArcRotateCamera, Color3, HemisphericLight, MeshBuilder, Scene, StandardMaterial, Vector3 } from '@babylonjs/core'
import { GlobalInstance } from './instance'

export function createAugmaScene() {
  const engine = GlobalInstance.engine
  const scene = new Scene(engine)

  // Add a basic light
  new HemisphericLight('light1', new Vector3(0, 2, 0), scene)

  // Add a camera for the non-VR view in browser
  const camera = new ArcRotateCamera('Camera', -(Math.PI / 4) * 3, Math.PI / 4, 10, new Vector3(0, 0, 0), scene)
  camera.attachControl(true)

  // Add a sphere to have something to look at
  const sphereD = 1.0
  const sphere = MeshBuilder.CreateSphere('xSphere', { segments: 16, diameter: sphereD }, scene)
  sphere.position.x = 0
  sphere.position.y = sphereD * 2
  sphere.position.z = 0
  const rMat = new StandardMaterial('matR', scene)
  rMat.diffuseColor = new Color3(1.0, 0, 0)
  sphere.material = rMat

  return scene
}
