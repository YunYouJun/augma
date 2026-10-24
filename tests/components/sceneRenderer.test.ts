import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { describe, expect, it, vi } from 'vitest'
import { createSceneRenderer } from '../../apps/ar/src/features/device/backdrop/sceneRenderer'

// Resolve the actual engine from its owning workspace package, without adding a root dependency.
const arRequire = createRequire(resolve('apps/ar/package.json'))
const { Engine } = await import(arRequire.resolve('@babylonjs/core/Engines/engine.js'))

describe('scene renderer unavailable GPU cleanup', () => {
  it.each(['unsupported', 'denied'] as const)('does not retain engines or canvas listeners when WebGL is %s', (failure) => {
    const enginesBefore = [...Engine.Instances]
    const onState = vi.fn()
    const createWorld = vi.fn()
    for (let attempt = 0; attempt < 3; attempt++) {
      const canvas = document.createElement('canvas')
      const addListener = vi.spyOn(canvas, 'addEventListener')
      vi.spyOn(canvas, 'getContext').mockImplementation(() => {
        if (failure === 'denied')
          throw new DOMException('Context access denied', 'SecurityError')
        return null
      })

      expect(() => createSceneRenderer(canvas, onState, createWorld)).toThrow(
        failure === 'unsupported' ? 'WebGL is unavailable' : 'Context access denied',
      )
      expect(Engine.Instances).toEqual(enginesBefore)
      expect(addListener).not.toHaveBeenCalled()
    }
    expect(onState).not.toHaveBeenCalled()
    expect(createWorld).not.toHaveBeenCalled()
  })
})
