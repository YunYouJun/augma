import { Color3, Engine, EnvironmentHelper, Scene, WebXRSessionManager } from '@babylonjs/core'
import { GlobalInstance } from './instance'

// Required for EnvironmentHelper
import '@babylonjs/core/Materials/Textures/Loaders'

// Enable GLTF/GLB loader for loading controller models from WebXR Input registry
import '@babylonjs/loaders/glTF'

// Without this next import, an error message like this occurs loading controller models:
//  Build of NodeMaterial failed" error when loading controller model
//  Uncaught (in promise) Build of NodeMaterial failed: input rgba from block
//  FragmentOutput[FragmentOutputBlock] is not connected and is not optional.
import '@babylonjs/core/Materials/Node/Blocks'
import { createAugmaScene } from './augma'

export function createEngine(canvas: HTMLCanvasElement) {
  const engine = new Engine(canvas, true)
  GlobalInstance.engine = engine
  GlobalInstance.canvas = canvas
  return engine
}

export async function createMainScene() {
  if (!GlobalInstance.engine)
    throw new Error('engine is not initialized')

  const engine = GlobalInstance.engine
  const scene = new Scene(engine)

  return scene
}

/**
 * create augma WebXR
 * @param canvas
 */
export async function createWebXR(canvas: HTMLCanvasElement) {
  const isSupportWebXR = 'xr' in navigator && (await WebXRSessionManager.IsSessionSupportedAsync('immersive-vr'))
  if (!isSupportWebXR)
    throw new Error('WebXR is not supported')

  const engine = createEngine(canvas)

  const augmaScene = createAugmaScene()
  const scene = augmaScene

  augmaScene.createDefaultXRExperienceAsync()

  // Create a default environment (skybox, ground mesh, etc)
  const envHelper = new EnvironmentHelper({
    skyboxSize: 30,
    groundColor: new Color3(0.5, 0.5, 0.5),
  }, scene)

  // Setup default WebXR experience
  // Use the enviroment floor to enable teleportation
  const xr = await augmaScene.createDefaultXRExperienceAsync({
    floorMeshes: [envHelper.ground],
    optionalFeatures: true,
  })

  engine.runRenderLoop(() => {
    augmaScene.render()
  })

  return {
    engine,

    xr,
  }
}
