import type { Camera, Engine } from '@babylonjs/core'

export const GlobalInstance: {
  canvas: HTMLCanvasElement | null
  engine: Engine | null
  mainCamera: Camera | null
} = {
  canvas: null,
  engine: null,
  mainCamera: null,
}
