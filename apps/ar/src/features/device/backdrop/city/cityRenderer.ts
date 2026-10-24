import type { SceneRendererState } from '../sceneRenderer'
import { createSceneRenderer } from '../sceneRenderer'
import { createCityWorld } from './cityWorld'

export function createCityRenderer(canvas: HTMLCanvasElement, onState: (state: SceneRendererState) => void) {
  return createSceneRenderer(canvas, onState, createCityWorld)
}
