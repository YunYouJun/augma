import type { SceneRendererState } from '../sceneRenderer'
import { createSceneRenderer } from '../sceneRenderer'
import { createGardenWorld } from './gardenWorld'

export function createGardenRenderer(canvas: HTMLCanvasElement, onState: (state: SceneRendererState) => void) {
  return createSceneRenderer(canvas, onState, createGardenWorld)
}
