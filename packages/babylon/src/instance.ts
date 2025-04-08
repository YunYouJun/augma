import type { AbstractEngine, Camera } from '@babylonjs/core'

export const GlobalInstance: {
  canvas: HTMLCanvasElement | null
  engine: AbstractEngine | null
  mainCamera: Camera | null
} = {
  canvas: null,
  engine: null,
  mainCamera: null,
}
