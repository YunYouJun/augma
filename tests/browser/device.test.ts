import type { Page } from '@playwright/test'
import { expect, test } from '@playwright/test'

async function openSystemApp(page: Page, name: string) {
  await page.getByRole('button', { name: '系统菜单', exact: true }).click()
  await page.getByRole('button', { name, exact: true }).click()
}

test('original empty view, weather toggle and keyboard close', async ({ page }) => {
  await page.setViewportSize({ width: 724, height: 656 })
  await page.goto('/ar/')
  await expect(page.locator('.ar-app')).toHaveCSS('background-color', 'rgb(117, 117, 117)')
  await expect(page.locator('.device-window')).toHaveCount(0)
  await expect(page.locator('.world-scene')).toHaveCount(0)
  await expect(page.locator('.dock-buttons > .orb-button')).toHaveCount(9)
  await expect(page.locator('.system-clock time')).toHaveCSS('color', 'rgb(255, 255, 255)')
  const weather = page.getByRole('button', { name: '天气', exact: true })
  await weather.click()
  await expect(page.locator('.weather-temperature')).toHaveText('-3°C')
  await page.getByLabel('天气示例城市').selectOption({ label: '上海市' })
  await expect(page.locator('.weather-temperature')).toHaveText('18°C')
  await page.keyboard.press('Escape')
  await expect(page.locator('.device-window')).toHaveCount(0)
  await expect(weather).toBeFocused()
  await weather.click()
  await weather.click()
  await expect(page.locator('.device-window')).toHaveCount(0)
  expect(await page.evaluate(() => document.documentElement.scrollHeight <= innerHeight)).toBe(true)
})

test('app panels can be moved, restored and kept within the workspace', async ({ page }) => {
  await page.setViewportSize({ width: 900, height: 700 })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '空间', exact: true }).click()
  const panel = page.locator('.device-window')
  const handle = page.getByLabel('移动空间面板，方向键微调，按住 Shift 加速')
  const initial = await panel.boundingBox()
  const grip = await handle.boundingBox()
  await page.mouse.move(grip!.x + 60, grip!.y + 20)
  await page.mouse.down()
  await page.mouse.move(grip!.x - 120, grip!.y + 110, { steps: 6 })
  await page.mouse.up()
  await expect(panel).toHaveClass(/is-positioned/)
  const moved = await panel.boundingBox()
  expect(moved!.x).toBeLessThan(initial!.x - 100)
  expect(moved!.y).toBeGreaterThanOrEqual(initial!.y)
  await expect(page.getByRole('button', { name: '扫描空间', exact: true })).toBeEnabled()

  await page.reload()
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await expect(panel).toHaveClass(/is-positioned/)
  const restored = await panel.boundingBox()
  expect(restored!.x).toBeCloseTo(moved!.x, 0)
  expect(restored!.y).toBeCloseTo(moved!.y, 0)
  await handle.focus()
  await page.keyboard.press('Shift+ArrowRight')
  const nudged = await panel.boundingBox()
  expect(nudged!.x).toBeCloseTo(restored!.x + 32, 0)

  await page.setViewportSize({ width: 390, height: 844 })
  await expect.poll(async () => {
    const small = await panel.boundingBox()
    return small!.x + small!.width
  }).toBeLessThanOrEqual(390)
  const small = await panel.boundingBox()
  expect(small!.x).toBeGreaterThanOrEqual(0)
  await page.getByRole('button', { name: '复位空间面板位置' }).click()
  await expect(panel).not.toHaveClass(/is-positioned/)
  await handle.focus()
  await page.keyboard.press('ArrowLeft')
  await expect(panel).toHaveClass(/is-positioned/)
  await openSystemApp(page, '设置')
  await page.getByRole('button', { name: '恢复默认设置', exact: true }).click()
  await page.getByRole('button', { name: '确认恢复' }).click()
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await expect(panel).not.toHaveClass(/is-positioned/)
})

test('scan, select an anchor, navigate and read device notifications', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/ar/')
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await page.getByRole('button', { name: '扫描空间', exact: true }).click()
  await expect(page.getByText('已识别 3 个空间锚点')).toBeVisible()
  await page.getByRole('button', { name: '固定空间锚点', exact: true }).click()
  await expect(page.getByRole('button', { name: '释放空间锚点' })).toHaveAttribute('aria-pressed', 'true')
  await page.getByRole('button', { name: '选择中央绿洲', exact: true }).click()
  await expect(page.locator('.selected-place h3')).toContainText('中央绿洲')
  await page.getByRole('button', { name: '导航到这里' }).click()
  await expect(page.locator('.spatial-map')).toBeVisible()
  for (let i = 0; i < 4; i++)
    await page.getByRole('button', { name: '前进一步' }).click()
  await expect(page.getByRole('progressbar', { name: '路线进度' })).toHaveAttribute('aria-valuenow', '100')
  await expect(page.locator('.route-instruction')).toContainText('已到达中央绿洲')
  await openSystemApp(page, '通知')
  await expect(page.getByRole('heading', { name: '已到达目的地', exact: true })).toBeVisible()
  await expect(page.locator('.notification-count')).toHaveCount(0)
  await page.getByRole('button', { name: '清空通知' }).click()
  await expect(page.getByRole('heading', { name: '通知已清空' })).toBeVisible()
  expect(errors).toEqual([])
})

test('sleep cancels a scan and waking restores device controls', async ({ page }) => {
  await page.goto('/ar/')
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await page.getByRole('button', { name: '扫描空间', exact: true }).click()
  await openSystemApp(page, '设备')
  await page.getByRole('button', { name: '待机', exact: true }).click()
  await page.getByRole('button', { name: '摄像头', exact: true }).click()
  await expect(page.getByRole('button', { name: '开启摄像头' })).toBeDisabled()
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await expect(page.getByRole('button', { name: '扫描空间', exact: true })).toBeDisabled()
  await expect(page.getByRole('progressbar', { name: '空间扫描' })).toHaveAttribute('aria-valuenow', '0')
  await page.getByRole('button', { name: '唤醒设备' }).click()
  await expect(page.getByRole('button', { name: '扫描空间', exact: true })).toBeEnabled()
  await page.getByRole('button', { name: '城市漫游', exact: true }).click()
  await expect(page.getByRole('button', { name: '选择光之美术馆' })).toBeVisible()
  await openSystemApp(page, '设备')
  await page.getByRole('button', { name: '断开', exact: true }).click()
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await expect(page.getByRole('button', { name: '选择光之美术馆' })).toHaveCount(0)
})

test('display settings persist and reset with keyboard focus restored', async ({ page }) => {
  await page.goto('/ar/')
  await openSystemApp(page, '设置')
  await page.getByRole('switch', { name: '深色视界' }).click()
  await page.getByRole('switch', { name: '专注模式' }).click()
  const opacity = page.getByRole('slider', { name: '面板不透明度' })
  await opacity.focus()
  await page.keyboard.press('Home')
  await expect(opacity).toHaveAttribute('aria-valuenow', '60')
  await expect(page.locator('.world-marker')).toHaveCount(0)
  await page.reload()
  await expect(page.locator('html')).toHaveAttribute('data-agm-theme', 'dark')
  await openSystemApp(page, '设置')
  await expect(page.getByRole('switch', { name: '专注模式' })).toBeChecked()
  await page.getByRole('button', { name: '恢复默认设置', exact: true }).click()
  const dialog = page.getByRole('dialog', { name: '恢复默认设置' })
  await expect(dialog).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(page.getByRole('button', { name: '恢复默认设置', exact: true })).toBeFocused()
  await page.getByRole('button', { name: '恢复默认设置', exact: true }).click()
  await page.getByRole('button', { name: '确认恢复' }).click()
  await expect(page.locator('html')).toHaveAttribute('data-agm-theme', 'light')
  await expect(page.getByRole('slider', { name: '面板不透明度' })).toHaveAttribute('aria-valuenow', '88')
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await expect(page.locator('.world-marker')).toHaveCount(3)
})

test('scene backdrop follows the space scene, yields to the camera and can return to plain gray', async ({ page }) => {
  await page.addInitScript(() => {
    // A blank canvas stream stands in for the camera in every browser engine.
    Object.defineProperty(navigator, 'mediaDevices', { configurable: true, value: { getUserMedia: async () => document.createElement('canvas').captureStream() } })
  })
  await page.goto('/ar/')
  const backdrop = page.locator('.scene-backdrop')
  await expect(backdrop.locator('.backdrop-scene.is-garden')).toBeVisible()
  await expect(page.locator('.ar-app')).toHaveCSS('background-color', 'rgb(117, 117, 117)')
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await page.getByRole('button', { name: '城市漫游', exact: true }).click()
  await expect(backdrop.locator('.backdrop-scene.is-city')).toBeVisible()
  await expect(backdrop.locator('.backdrop-scene.is-garden')).toHaveCount(0)
  await page.getByRole('button', { name: '摄像头', exact: true }).click()
  await page.getByRole('button', { name: '开启摄像头' }).click()
  await expect(backdrop).toHaveCount(0)
  await page.locator('.camera-actions').getByRole('button', { name: '关闭摄像头' }).click()
  await expect(backdrop.locator('.backdrop-scene.is-city')).toBeVisible()
  await openSystemApp(page, '设置')
  const toggle = page.getByRole('switch', { name: '场景背景' })
  await expect(toggle).toBeChecked()
  await toggle.click()
  await expect(backdrop).toHaveCount(0)
  await page.reload()
  await expect(page.locator('.device-window')).toHaveCount(0)
  await expect(backdrop).toHaveCount(0)
  await openSystemApp(page, '设置')
  await page.getByRole('button', { name: '恢复默认设置', exact: true }).click()
  await page.getByRole('button', { name: '确认恢复' }).click()
  await expect(page.getByRole('switch', { name: '场景背景' })).toBeChecked()
  await expect(backdrop).toHaveCount(1)
})

type SceneKey = 'city' | 'garden'

async function browserSupportsWebGL(page: Page) {
  // Probe the browser before loading application code, so a scene initialization bug cannot cause a skip.
  const supported = await page.evaluate(() => {
    const canvas = document.createElement('canvas')
    const options: WebGLContextAttributes = {
      alpha: false,
      stencil: false,
      depth: true,
      antialias: true,
      premultipliedAlpha: true,
      preserveDrawingBuffer: false,
      powerPreference: 'low-power',
    }
    const context = canvas.getContext('webgl2', options) ?? canvas.getContext('webgl', options)
    context?.getExtension('WEBGL_lose_context')?.loseContext()
    return context !== null
  })
  // Keep a required software-WebGL lane: CI must not silently skip every GPU assertion.
  if (page.context().browser()?.browserType().name() === 'chromium')
    expect(supported, 'Chromium must provide WebGL for the GPU regression suite').toBe(true)
  return supported
}

async function expectWebGLScene(page: Page, scene: SceneKey, supported: boolean) {
  const scenery = page.locator(`.backdrop-scene.is-${scene}`)
  if (!supported) {
    // Headless browsers without a graphics backend must still render the supported fallback.
    await expect(scenery).toHaveAttribute('data-renderer', 'fallback')
    await expect(scenery).toBeVisible()
    await expect(scenery).toHaveCSS('background-image', /linear-gradient/)
    await expect(scenery.locator(`canvas.${scene}-landscape`)).toHaveCSS('opacity', '0')
    test.skip(true, 'Browser cannot create a WebGL context; visible fallback verified before skipping GPU-only assertions')
  }
  await expect(scenery).toHaveAttribute('data-renderer', 'webgl')
}

async function observeSceneFrames(page: Page) {
  await page.addInitScript(() => {
    const state = { city: 0, garden: 0 }
    Object.assign(window, { __sceneFrames: state })
    for (const prototype of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
      if (!prototype)
        continue
      const drawElements = prototype.drawElements
      Object.defineProperty(prototype, 'drawElements', {
        configurable: true,
        value(this: WebGLRenderingContext, ...args: Parameters<WebGLRenderingContext['drawElements']>) {
          if (this.canvas instanceof HTMLCanvasElement) {
            for (const scene of ['city', 'garden'] as const) {
              if (this.canvas.classList.contains(`${scene}-landscape`))
                state[scene]++
            }
          }
          return Reflect.apply(drawElements, this, args)
        },
      })
    }
  })
}

async function sceneFrameCount(page: Page, scene: SceneKey) {
  return page.evaluate(scene => (window as typeof window & { __sceneFrames: Record<SceneKey, number> }).__sceneFrames[scene], scene)
}

async function sceneMotionBudgetLimited(page: Page, scene: SceneKey) {
  return page.locator(`.backdrop-scene.is-${scene}`).evaluate(element => element.classList.contains('is-still'))
}

async function skipIfSceneMotionBudgetLimited(page: Page, scene: SceneKey) {
  test.skip(await sceneMotionBudgetLimited(page, scene), 'The current GPU load triggered the low-frame-rate motion budget')
}

async function expectSceneFramesToAdvance(page: Page, scene: SceneKey, before: number) {
  await expect.poll(async () => await sceneFrameCount(page, scene) > before || await sceneMotionBudgetLimited(page, scene)).toBe(true)
  await skipIfSceneMotionBudgetLimited(page, scene)
  expect(await sceneFrameCount(page, scene)).toBeGreaterThan(before)
}

async function expectSceneFramesStopped(page: Page, scene: SceneKey) {
  // Allow a pending resize or context-recovery frame, then observe a real interval without GPU draws.
  await expect.poll(async () => {
    const before = await sceneFrameCount(page, scene)
    await page.waitForTimeout(300)
    return await sceneFrameCount(page, scene) - before
  }).toBe(0)
}

async function selectNativeScene(page: Page, scene: SceneKey) {
  await page.evaluate((scene) => {
    window.dispatchEvent(new CustomEvent('augma:native-action', { detail: { action: 'scene', value: scene } }))
  }, scene)
}

async function openNativeScene(page: Page, scene: SceneKey) {
  // Keep GPU motion checks within a modest desktop viewport on software renderers.
  await page.setViewportSize({ width: 900, height: 700 })
  await page.addInitScript(() => {
    Object.assign(window, {
      __AUGMA_DESKTOP_NATIVE_CONTROLS__: true,
      __AUGMA_DESKTOP_MODULE__: 'space',
      webkit: { messageHandlers: { nativeState: { postMessage() {} } } },
    })
  })
  await page.goto('/ar/')
  await selectNativeScene(page, scene)
}

for (const scene of ['city', 'garden'] as const) {
  const sceneName = scene === 'city' ? '城市漫游' : '空中庭院'

  test(`native 3D ${scene} renders motion without a web panel and stops for reduced motion`, async ({ page }) => {
    const webgl = await browserSupportsWebGL(page)
    await page.emulateMedia({ reducedMotion: 'no-preference' })
    await observeSceneFrames(page)
    await openNativeScene(page, scene)
    const view = page.locator('.ar-app')
    const backdrop = page.locator('.scene-backdrop')
    const scenery = backdrop.locator(`.is-${scene}`)
    const canvas = scenery.locator(`canvas.${scene}-landscape`)
    await expect(view).toHaveClass(/has-native-controls/)
    await page.evaluate(() => {
      window.dispatchEvent(new CustomEvent('augma:native-action', { detail: { action: 'setting', value: { key: 'depthMotion', value: true } } }))
    })
    await expectWebGLScene(page, scene, webgl)
    await expect(canvas).toBeVisible()
    await expect(view).toHaveClass(/has-depth/)
    await expect(view).not.toHaveClass(/has-window/)
    await expect(page.locator('.device-window')).toHaveCount(0)
    await expect(backdrop).not.toHaveClass(/is-paused/)
    await expect(canvas).toHaveCSS('filter', 'none')
    await expect(scenery).not.toHaveClass(/backdrop-fade-enter-active/)
    const rendered = await sceneFrameCount(page, scene)
    expect(rendered).toBeGreaterThan(0)
    await expectSceneFramesToAdvance(page, scene, rendered)
    // The GPU must draw a changing scene, rather than repeatedly submit one stationary frame.
    const screenshotOptions = { style: '.world-scene { visibility: hidden !important; }' }
    const image = await canvas.screenshot(screenshotOptions)
    await expect.poll(async () => !(await canvas.screenshot(screenshotOptions)).equals(image) || await sceneMotionBudgetLimited(page, scene)).toBe(true)
    await skipIfSceneMotionBudgetLimited(page, scene)

    await page.emulateMedia({ reducedMotion: 'reduce' })
    await expect(canvas).toBeVisible()
    await expectSceneFramesStopped(page, scene)
    await page.emulateMedia({ reducedMotion: 'no-preference' })
    const stopped = await sceneFrameCount(page, scene)
    await expectSceneFramesToAdvance(page, scene, stopped)
  })

  test(`3D ${scene} stops rendering behind a web space panel and resumes when it closes`, async ({ page }) => {
    const webgl = await browserSupportsWebGL(page)
    await page.setViewportSize({ width: 900, height: 700 })
    await page.emulateMedia({ reducedMotion: 'no-preference' })
    await observeSceneFrames(page)
    await page.goto('/ar/')
    await page.getByRole('button', { name: '空间', exact: true }).click()
    await page.getByRole('button', { name: sceneName, exact: true }).click()
    const backdrop = page.locator('.scene-backdrop')
    await expectWebGLScene(page, scene, webgl)
    await expect(backdrop.locator(`canvas.${scene}-landscape`)).toBeVisible()
    await expect(page.locator('.ar-app')).toHaveClass(/has-window/)
    await expect(backdrop).toHaveClass(/is-paused/)
    expect(await sceneFrameCount(page, scene)).toBeGreaterThan(0)
    await expectSceneFramesStopped(page, scene)

    await page.keyboard.press('Escape')
    await expect(page.locator('.device-window')).toHaveCount(0)
    await expect(backdrop).not.toHaveClass(/is-paused/)
    const paused = await sceneFrameCount(page, scene)
    await expectSceneFramesToAdvance(page, scene, paused)
  })

  test(`${scene} keeps a visible background when WebGL is unavailable`, async ({ page }) => {
    const errors: string[] = []
    page.on('pageerror', error => errors.push(error.message))
    await page.addInitScript(() => {
      const getContext = HTMLCanvasElement.prototype.getContext
      Object.defineProperty(HTMLCanvasElement.prototype, 'getContext', {
        configurable: true,
        value(this: HTMLCanvasElement, contextId: string, ...options: unknown[]) {
          if (['webgl', 'webgl2', 'experimental-webgl'].includes(contextId))
            return null
          return Reflect.apply(getContext, this, [contextId, ...options])
        },
      })
    })
    await openNativeScene(page, scene)
    const scenery = page.locator(`.backdrop-scene.is-${scene}`)
    await expect(scenery).toHaveAttribute('data-renderer', 'fallback')
    await expect(scenery.locator(`canvas.${scene}-landscape`)).toHaveCSS('opacity', '0')
    await expect(scenery).toBeVisible()
    await expect(scenery).toHaveCSS('background-image', /linear-gradient/)
    expect(errors).toEqual([])
  })

  test(`${scene} recovers its 3D scene after a lost WebGL context`, async ({ page }) => {
    const webgl = await browserSupportsWebGL(page)
    await page.emulateMedia({ reducedMotion: 'no-preference' })
    await observeSceneFrames(page)
    await openNativeScene(page, scene)
    const scenery = page.locator(`.backdrop-scene.is-${scene}`)
    await expectWebGLScene(page, scene, webgl)
    const canLoseContext = await scenery.locator('canvas').evaluate((element) => {
      const canvas = element as HTMLCanvasElement
      const context = canvas.getContext('webgl2') || canvas.getContext('webgl')
      const extension = context?.getExtension('WEBGL_lose_context')
      if (!extension)
        return false
      Object.assign(window, { __sceneContextExtension: extension })
      extension.loseContext()
      return true
    })
    test.skip(!canLoseContext, 'This browser does not provide WEBGL_lose_context')
    await expect(scenery).toHaveAttribute('data-renderer', 'fallback')
    await expect(scenery).toBeVisible()
    await expect(scenery).toHaveCSS('background-image', /linear-gradient/)
    await expectSceneFramesStopped(page, scene)
    await page.evaluate(() => {
      (window as typeof window & { __sceneContextExtension: WEBGL_lose_context }).__sceneContextExtension.restoreContext()
    })
    await expect(scenery).toHaveAttribute('data-renderer', 'webgl')
    await expect(scenery.locator(`canvas.${scene}-landscape`)).toBeVisible()
    const restored = await sceneFrameCount(page, scene)
    await expectSceneFramesToAdvance(page, scene, restored)
  })

  test(`switching away from the 3D ${scene} stops GPU work and returning creates a working scene`, async ({ page }) => {
    const webgl = await browserSupportsWebGL(page)
    await page.emulateMedia({ reducedMotion: 'no-preference' })
    await observeSceneFrames(page)
    await openNativeScene(page, scene)
    const scenery = page.locator(`.backdrop-scene.is-${scene}`)
    await expectWebGLScene(page, scene, webgl)
    const otherScene = scene === 'city' ? 'garden' : 'city'
    await selectNativeScene(page, otherScene)
    await expect(scenery).toHaveCount(0)
    await expect(page.locator(`.backdrop-scene.is-${otherScene}`)).toHaveAttribute('data-renderer', 'webgl')
    await expectSceneFramesStopped(page, scene)
    const otherRendered = await sceneFrameCount(page, otherScene)
    await expectSceneFramesToAdvance(page, otherScene, otherRendered)
    await selectNativeScene(page, scene)
    await expect(scenery).toHaveAttribute('data-renderer', 'webgl')
    const recreated = await sceneFrameCount(page, scene)
    await expectSceneFramesToAdvance(page, scene, recreated)
    await expect(page.locator(`.backdrop-scene.is-${otherScene}`)).toHaveCount(0)
    await expectSceneFramesStopped(page, otherScene)
  })
}

test('sound playback survives panel changes and stops on standby', async ({ page }) => {
  await page.addInitScript(() => {
    class TestAudioContext {
      destination = {}
      currentTime = 0
      createGain() {
        return { gain: { value: 0, setTargetAtTime() {} }, connect() {}, disconnect() {} }
      }

      createOscillator() {
        return { frequency: { value: 0 }, detune: { value: 0 }, connect() {}, start() {}, stop() {}, disconnect() {} }
      }

      async resume() {}
      async suspend() {}
      async close() {}
    }
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: TestAudioContext })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '声音', exact: true }).click()
  await page.getByRole('button', { name: '播放声音', exact: true }).click()
  await expect(page.getByRole('button', { name: '暂停声音' })).toBeVisible()
  await page.getByRole('button', { name: '下一首' }).click()
  await expect(page.getByRole('heading', { name: '浮游时刻' })).toBeVisible()
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await page.getByRole('button', { name: '声音', exact: true }).click()
  await expect(page.getByRole('button', { name: '暂停声音' })).toBeVisible()
  await openSystemApp(page, '设备')
  await page.getByRole('button', { name: '待机', exact: true }).click()
  await page.getByRole('button', { name: '声音', exact: true }).click()
  await expect(page.getByRole('button', { name: '播放声音', exact: true })).toBeDisabled()
})

test('mobile anchors, route controls and HUD recovery remain usable', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '空间', exact: true }).click()
  await page.getByRole('button', { name: '选择玻璃回廊' }).click()
  await expect(page.locator('.selected-place h3')).toContainText('玻璃回廊')
  await page.getByRole('button', { name: '导航', exact: true }).click()
  await page.getByRole('button', { name: '显示到中央绿洲的路线' }).click()
  await expect(page.getByRole('button', { name: '中央绿洲 45 m', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await page.getByRole('button', { name: '开始模拟导航' }).click()
  await page.getByRole('button', { name: '前进一步' }).click()
  await expect(page.locator('.route-stops [aria-current="step"]')).toContainText('前方步道')
  await page.getByRole('switch', { name: '显示 HUD' }).click()
  await expect(page.locator('.device-window')).toHaveCount(0)
  await page.getByRole('switch', { name: '显示 HUD' }).click()
  await expect(page.getByRole('button', { name: '前进一步' })).toBeVisible()
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
})

test('depth and curves are independent, persist and stop for reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/ar/')
  const view = page.locator('.ar-app')
  await openSystemApp(page, '设置')
  await expect(page.getByRole('switch', { name: '景深动画' })).not.toBeChecked()
  await expect(page.getByRole('switch', { name: '弧线视界' })).not.toBeChecked()
  await expect(page.locator('.system-rule')).toBeVisible()
  await page.getByRole('switch', { name: '景深动画' }).click()
  await expect(view).toHaveClass(/has-depth/)
  // An open panel pulls focus to the HUD and softens the scenery behind it.
  const scenery = page.locator('.scene-backdrop .art-mid').first()
  await expect(scenery).toHaveCSS('filter', 'blur(2.4px)')
  await expect(page.locator('.system-arc')).toHaveCount(0)
  await page.mouse.move(80, 280)
  await expect.poll(() => view.evaluate(element => element.style.getPropertyValue('--depth-x'))).not.toBe('')
  await expect(page.locator('.device-window')).not.toHaveCSS('translate', 'none')
  await page.getByRole('switch', { name: '弧线视界' }).click()
  await expect(page.locator('.system-arc')).toBeVisible()
  await expect(page.locator('.dock-arc')).toBeVisible()
  const edge = page.getByRole('button', { name: '镜像画面', exact: true })
  await expect(edge).toHaveCSS('translate', '0px 12px')
  await page.reload()
  await openSystemApp(page, '设置')
  await expect(page.getByRole('switch', { name: '景深动画' })).toBeChecked()
  await expect(page.getByRole('switch', { name: '弧线视界' })).toBeChecked()
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await expect(view).not.toHaveClass(/has-depth/)
  await expect(page.getByText('系统已开启减少动态效果，景深动画暂停；弧线外观仍可使用。')).toBeVisible()
  await expect(page.locator('.system-arc')).toBeVisible()
  await expect(page.locator('.device-window')).toHaveCSS('animation-name', 'none')
  await expect(scenery).toHaveCSS('filter', 'none')
  await page.mouse.move(90, 300)
  await expect.poll(() => view.evaluate(element => element.style.getPropertyValue('--depth-x'))).toBe('')
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await expect(view).toHaveClass(/has-depth/)
  await page.getByRole('switch', { name: '景深动画' }).click()
  await expect(view).not.toHaveClass(/has-depth/)
  await expect(page.locator('.system-arc')).toBeVisible()
  await page.getByRole('button', { name: '恢复默认设置', exact: true }).click()
  await page.getByRole('button', { name: '确认恢复' }).click()
  await expect(page.getByRole('switch', { name: '弧线视界' })).not.toBeChecked()
  await expect(page.locator('.system-rule')).toBeVisible()
  await expect(edge).toHaveCSS('translate', 'none')
})

test('curved mobile HUD keeps controls reachable and hiding HUD stops depth', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/ar/')
  await openSystemApp(page, '设置')
  await page.getByRole('switch', { name: '景深动画' }).click()
  await page.getByRole('switch', { name: '弧线视界' }).click()
  await page.getByRole('button', { name: '导航', exact: true }).click()
  await page.getByRole('button', { name: '显示到中央绿洲的路线' }).click()
  await page.getByRole('button', { name: '开始模拟导航' }).click()
  await page.getByRole('button', { name: '前进一步' }).click()
  await expect(page.getByRole('progressbar', { name: '路线进度' })).toHaveAttribute('aria-valuenow', '25')
  await page.getByRole('switch', { name: '显示 HUD' }).click()
  await expect(page.locator('.ar-app')).not.toHaveClass(/has-depth/)
  await page.getByRole('switch', { name: '显示 HUD' }).click()
  await expect(page.locator('.ar-app')).toHaveClass(/has-depth/)
  const docs = await page.getByRole('link', { name: '组件文档' }).boundingBox()
  expect(docs!.x + docs!.width).toBeLessThanOrEqual(390)
  expect(docs!.y + docs!.height).toBeLessThanOrEqual(844)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth && document.documentElement.scrollHeight <= innerHeight)).toBe(true)
})
