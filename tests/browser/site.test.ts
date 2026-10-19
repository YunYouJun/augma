import { expect, test } from '@playwright/test'

const components = [
  'button',
  'icon-button',
  'input',
  'select',
  'switch',
  'slider',
  'dialog',
  'tooltip',
  'toast',
  'panel',
  'hud-status',
  'hud-progress',
  'hud-gauge',
]
test('home settings, HUD visibility and responsive layout', async ({
  page,
}) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/')
  await expect(page).toHaveTitle(/Augma/)
  await expect(
    page.getByRole('heading', { name: '界面，浮现于现实。' }),
  ).toBeVisible()
  await page.getByRole('button', { name: '调整界面' }).click()
  const dialog = page.getByRole('dialog', { name: '调整界面' })
  await expect(dialog).toBeVisible()
  await dialog.getByRole('slider', { name: '示例进度' }).focus()
  await page.keyboard.press('ArrowRight')
  await expect(dialog.getByRole('slider', { name: '示例进度' })).toHaveAttribute(
    'aria-valuenow',
    '73',
  )
  await page.keyboard.press('Escape')
  await expect(dialog).not.toBeVisible()
  await expect(page.getByRole('button', { name: '调整界面' })).toBeFocused()
  await page.getByRole('switch', { name: '显示 HUD' }).click()
  await expect(page.getByText('HUD 已隐藏，可通过左侧开关恢复。')).toBeVisible()
  await page.setViewportSize({ width: 390, height: 844 })
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true)
  expect(errors).toEqual([])
})
test('component catalog, previews and source are available', async ({
  page,
}) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/components/')
  await page.getByLabel('查找组件').fill('Dialog')
  await expect(page.locator('.catalog-list li')).toHaveCount(1)
  for (const name of components) {
    await page.goto(`/components/${name}`)
    await expect(page.locator('.demo-canvas')).toBeVisible()
    await expect(page.locator('.demo-canvas')).toHaveAttribute('aria-busy', 'false')
    await page.getByText('查看 Vue 源码', { exact: true }).click()
    await expect(page.locator('.demo-source pre')).toContainText('from \'augma\'')
  }
  expect(errors).toEqual([])
})
test('select keyboard, input validation, switch and toast', async ({
  page,
}) => {
  await page.goto('/components/select')
  await page.getByRole('combobox', { name: '显示模式' }).click()
  await page.getByRole('option', { name: '探索模式' }).click()
  await expect(page.locator('output')).toContainText('explore')
  await page.goto('/components/input')
  await page.getByLabel('设备名称').fill('')
  await expect(page.getByText('请输入设备名称', { exact: true })).toBeVisible()
  await page.goto('/components/switch')
  await page.getByRole('switch', { name: '显示 HUD' }).focus()
  await page.keyboard.press('Space')
  await expect(page.locator('output')).toContainText('HUD 已关闭')
  await page.goto('/components/toast')
  await page.getByRole('button', { name: '保存设置' }).click()
  await expect(page.getByText('设置已保存', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: '关闭通知' }).click()
  await expect(page.getByText('设置已保存', { exact: true })).not.toBeVisible()
})
test('AR enters without requesting camera permission', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: {
        getUserMedia: () =>
          Promise.reject(new DOMException('Denied', 'NotAllowedError')),
      },
    })
  })
  const requests: string[] = []
  page.on('request', request => requests.push(request.url()))
  await page.goto('/ar/')
  await expect(page.locator('.device-window')).toHaveCount(0)
  await expect(page.getByRole('alert')).toHaveCount(0)
  expect(requests.some(url => url.includes('xrRuntime'))).toBe(false)
  await page.getByRole('button', { name: '摄像头', exact: true }).click()
  await page.getByRole('button', { name: '开启摄像头' }).click()
  await expect(page.getByRole('alert')).toContainText('权限')
  await page.getByRole('switch', { name: '显示 HUD' }).click()
  await expect(page.locator('.device-window')).toHaveCount(0)
  expect(errors).toEqual([])
})
test('machine-readable endpoints and canonical origin', async ({
  page,
  request,
}) => {
  for (const path of [
    '/llms.txt',
    '/llms-full.txt',
    '/components.json',
    '/r/button.json',
    '/markdown/guide/index.md',
  ])
    expect((await request.get(path)).ok(), path).toBe(true)
  const contract = await (await request.get('/components.json')).json()
  expect(contract.components).toHaveLength(13)
  await page.goto('/components/button')
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    'href',
    'https://augma.yunyoujun.cn/components/button',
  )
})

test('theme persists, tooltip dismisses and motion preference is respected', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/components/tooltip')
  await page.getByRole('switch', { name: '切换深色主题' }).click()
  await expect(page.locator('html')).toHaveClass(/dark/)
  await page.reload()
  await expect(page.locator('html')).toHaveClass(/dark/)
  await expect(page.locator('.demo-canvas')).toHaveAttribute('aria-busy', 'false')
  const tooltipTrigger = page.getByRole('button', { name: '恢复默认', exact: true })
  await tooltipTrigger.focus()
  await expect(tooltipTrigger).toBeFocused()
  await expect(page.locator('.agm-tooltip')).toContainText('恢复默认的显示参数')
  await expect(page.getByRole('button', { name: '恢复默认', exact: true })).toHaveAccessibleDescription('恢复默认的显示参数')
  await page.keyboard.press('Escape')
  await expect(page.locator('.agm-tooltip')).not.toBeVisible()
  await page.goto('/components/hud-progress')
  const pending = page.locator('[data-indeterminate="true"] .agm-progress-fill')
  await expect(pending).toHaveCSS('animation-name', 'none')
  await page.setViewportSize({ width: 390, height: 844 })
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true)
})

test('compositions work with public component APIs', async ({ page }) => {
  await page.goto('/showcase/')
  await page.getByRole('combobox', { name: '场景模式' }).focus()
  await page.keyboard.press('Enter')
  await expect(page.getByRole('option', { name: '专注', exact: true })).toBeFocused()
  await page.keyboard.press('ArrowDown')
  await expect(page.getByRole('option', { name: '探索', exact: true })).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(page.locator('.control-example > output')).toContainText('探索')
  await page.getByRole('button', { name: '恢复默认设置' }).click()
  await expect(page.locator('.control-example > output')).toContainText('专注')
  await page.getByRole('button', { name: '推进进度' }).click()
  await expect(
    page.locator('.theme-example [role="progressbar"]'),
  ).toHaveAttribute('aria-valuenow', '50')
  await expect(page.locator('.composition-gallery .demo-source')).toHaveCount(3)
})

test('select remains usable inside a modal and restores focus', async ({ page }) => {
  await page.goto('/components/dialog')
  const trigger = page.getByRole('button', { name: '打开设置' })
  await trigger.click()
  await page.getByRole('combobox', { name: '显示模式' }).click()
  await page.getByRole('option', { name: '探索', exact: true }).click()
  await expect(page.getByRole('combobox')).toContainText('探索')
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).not.toBeVisible()
  await expect(trigger).toBeFocused()
})

test('catalog combines category and search, and recovers from empty results', async ({ page }) => {
  await page.goto('/components/')
  const filters = page.getByRole('group', { name: '组件分类' })
  await filters.getByRole('button', { name: '反馈', exact: true }).click()
  await expect(page.locator('.catalog-list li')).toHaveCount(3)
  await page.getByLabel('查找组件').fill('Dialog')
  await expect(page.locator('.catalog-list li')).toHaveCount(1)
  await expect(page.locator('.catalog-count')).toHaveText('显示 1 / 13 个组件')
  await page.getByLabel('查找组件').fill('不存在的组件')
  await expect(page.locator('.catalog-list li')).toHaveCount(0)
  await page.getByRole('button', { name: '清除筛选' }).click()
  await expect(page.locator('.catalog-list li')).toHaveCount(13)
  await expect(filters.getByRole('button', { name: '全部', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await page.setViewportSize({ width: 390, height: 844 })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.locator('.catalog-list a').first().focus()
  await page.keyboard.press('Enter')
  await expect(page).toHaveURL(/\/components\/button$/)
})

test('select validation preserves guidance and clears after a keyboard selection', async ({ page }) => {
  await page.goto('/components/select')
  await page.getByRole('button', { name: '确认启动模式' }).click()
  const select = page.getByRole('combobox', { name: '启动模式' })
  await expect(select).toHaveAttribute('aria-invalid', 'true')
  await expect(select).toHaveAccessibleDescription('启动前请选择一个可用模式。 请选择启动模式')
  await select.focus()
  await page.keyboard.press('Enter')
  await page.keyboard.press('End')
  await expect(page.getByRole('option', { name: '探索模式', exact: true })).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(select).toHaveAttribute('aria-invalid', 'false')
  await expect(select).toHaveAccessibleDescription('启动前请选择一个可用模式。')
  await expect(select).toBeFocused()
  await page.getByRole('button', { name: '重置示例' }).click()
  await expect(select).toHaveText('请选择')
  await expect(page.getByText('请选择启动模式', { exact: true })).toHaveCount(0)
})

test('panel footer and toast states give feedback and support resetting', async ({ page }) => {
  await page.goto('/components/panel')
  await page.getByRole('button', { name: '完成同步' }).click()
  await expect(page.getByRole('progressbar', { name: '示例进度' })).toHaveAttribute('aria-valuenow', '100')
  await expect(page.getByRole('status')).toContainText('已同步')
  await page.getByRole('button', { name: '重置示例' }).click()
  await expect(page.getByRole('progressbar', { name: '示例进度' })).toHaveAttribute('aria-valuenow', '72')
  await page.goto('/components/toast')
  for (const [button, tone, title] of [
    ['显示提醒', 'warning', '电量较低'],
    ['模拟失败', 'danger', '同步未完成'],
    ['显示消息', 'neutral', '预览模式'],
    ['保存设置', 'success', '设置已保存'],
  ]) {
    await page.getByRole('button', { name: button, exact: true }).click()
    await expect(page.locator('.agm-toast')).toHaveAttribute('data-tone', tone)
    await expect(page.locator('.agm-toast-title')).toHaveText(title)
  }
  await page.getByRole('button', { name: '重置示例' }).click()
  await expect(page.locator('.agm-toast')).toHaveCount(0)
})

test('theme samples stay independent and unknown ring progress respects reduced motion', async ({ page }) => {
  await page.goto('/design/')
  const light = page.getByRole('region', { name: '浅色主题示例' })
  const dark = page.getByRole('region', { name: '深色主题示例' })
  await expect(light).toHaveCSS('background-color', 'rgb(243, 246, 248)')
  await expect(dark).toHaveCSS('background-color', 'rgb(27, 41, 54)')
  await page.getByRole('switch', { name: '切换深色主题' }).click()
  await expect(light).toHaveCSS('background-color', 'rgb(243, 246, 248)')
  await dark.getByRole('switch', { name: '显示界面' }).click()
  await expect(dark.getByRole('progressbar')).toHaveCount(0)
  await expect(light.getByRole('progressbar')).toBeVisible()
  await dark.getByRole('button', { name: '恢复默认' }).click()
  await expect(dark.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '72')
  await page.setViewportSize({ width: 390, height: 844 })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.goto('/components/hud-progress')
  const ring = page.locator('[data-indeterminate="true"] .agm-progress-ring')
  await expect(ring).toHaveCSS('animation-name', 'agm-ring')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await expect(ring).toHaveCSS('animation-name', 'none')
})

// One test per page: loading every heavy page in one tab crashed WebKit on Linux CI.
for (const path of ['/', '/showcase/', '/components/', '/en/', '/en/showcase/', '/ja/', '/ja/components/']) {
  test(`${path} has no horizontal scroll at 390px`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(path)
    await page.waitForLoadState('networkidle')
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  })
}

test('home shows install command, release line and AR demo entry', async ({ page }) => {
  await page.goto('/')
  await expect(page.locator('.hero-install code')).toHaveText('pnpm add augma')
  await expect(page.locator('.hero-install small')).toHaveText(/^v\d+\.\d+ · 13 个组件 · MIT$/)
  const demo = page.getByRole('region', { name: 'AR 演示' })
  await expect(demo).toContainText('还原自原版 Augma 网页的设备界面')
  await expect(demo.getByRole('link', { name: '打开 AR 演示' })).toHaveAttribute('href', '/ar/')
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute('content', /\/og\.jpg$/)
  await page.goto('/showcase/')
  await expect(page.locator('.device-stage')).toHaveCount(0)
  await expect(page.getByRole('heading', { name: '从一个按钮，到一整个视界' })).toHaveCount(0)
})

test('hero HUD rings stay concentric while they spin', async ({ page }) => {
  await page.goto('/')
  const offsets = await page.evaluate(() => {
    // Freeze every layer mid-spin; a wrong transform-origin swings the rings off center.
    for (const animation of document.querySelector('.hud-orbit')!.getAnimations({ subtree: true })) {
      animation.pause()
      animation.currentTime = 9000
    }
    const svg = document.querySelector('.hud-orbit svg')!.getBoundingClientRect()
    return [...document.querySelectorAll('.hud-orbit-layer circle')].map((circle) => {
      const box = circle.getBoundingClientRect()
      return Math.hypot(box.x + box.width / 2 - svg.x - svg.width / 2, box.y + box.height / 2 - svg.y - svg.height / 2)
    })
  })
  expect(offsets).toHaveLength(5)
  for (const offset of offsets)
    expect(offset).toBeLessThan(1)
})

test('macOS client is downloadable from the home page and its guide', async ({ page }) => {
  await page.goto('/')
  const demo = page.getByRole('region', { name: 'AR 演示' })
  await demo.getByRole('link', { name: 'macOS 客户端' }).click()
  await expect(page).toHaveURL(/\/guide\/macos$/)
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/macOS 客户端/)
  await expect(page.getByRole('link', { name: '下载 Augma for macOS' })).toHaveAttribute(
    'href',
    'https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS.zip',
  )
})

test('English and Japanese docs are translated and the language switcher keeps the page', async ({ page }) => {
  await page.goto('/en/')
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US')
  await expect(page.getByRole('heading', { name: 'Interfaces that surface in reality.' })).toBeVisible()
  await expect(page.locator('.hero-install small')).toHaveText(/^v\d+\.\d+ · 13 components · MIT$/)
  await expect(page.getByRole('link', { name: 'Browse components' })).toHaveAttribute('href', '/en/components/')

  await page.goto('/ja/')
  await expect(page.locator('html')).toHaveAttribute('lang', 'ja-JP')
  await expect(page.getByRole('heading', { name: 'インターフェースが、現実に浮かび上がる。' })).toBeVisible()

  await page.goto('/ja/guide/')
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/クイックスタート/)
  await page.getByRole('button', { name: '言語を切り替え' }).click()
  await page.getByRole('link', { name: 'English', exact: true }).click()
  await expect(page).toHaveURL(/\/en\/guide\/$/)
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/Quick start/)

  // Component pages are generated for every locale, so switching never lands on a missing page.
  await page.goto('/en/components/button')
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/^Button/)
  await expect(page.getByText('View Vue source', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Change language' }).click()
  await page.getByRole('link', { name: '简体中文', exact: true }).click()
  await expect(page).toHaveURL(/\/components\/button$/)
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/Button 按钮/)
})

test('live examples and their source follow the docs language', async ({ page }) => {
  await page.goto('/en/components/button')
  await expect(page.locator('.demo-canvas')).toHaveAttribute('aria-busy', 'false')
  await expect(page.getByRole('button', { name: 'Connect device', exact: true })).toBeVisible()
  await page.getByText('View Vue source', { exact: true }).click()
  const source = page.locator('.demo-source pre')
  await expect(source).toContainText('<AgmButton @click="count++">Connect device</AgmButton>')
  expect(await source.textContent()).not.toMatch(/\p{Script=Han}/u)
  await page.getByRole('button', { name: 'Change language' }).click()
  await page.getByRole('link', { name: '日本語', exact: true }).click()
  await expect(page).toHaveURL(/\/ja\/components\/button$/)
  await expect(page.getByRole('button', { name: 'デバイスを接続', exact: true })).toBeVisible()
  await page.getByText('Vue のソースを表示', { exact: true }).click()
  await expect(page.locator('.demo-source pre')).toContainText('デバイスを接続')

  await page.goto('/en/showcase/')
  await page.getByRole('combobox', { name: 'Scene mode' }).click()
  await page.getByRole('option', { name: 'Explore', exact: true }).click()
  await expect(page.locator('.control-example > output')).toContainText('Current: Explore · Navigation on')
  await page.getByRole('button', { name: 'Advance progress' }).click()
  await expect(page.getByRole('progressbar', { name: 'Sample progress' })).toHaveAttribute('aria-valuenow', '50')
  await page.goto('/ja/showcase/')
  await expect(page.getByRole('combobox', { name: 'シーンモード' })).toBeVisible()
  await expect(page.getByRole('button', { name: '初期設定に戻す' })).toBeVisible()
})

test('links into the AR demo carry the docs language over', async ({ page }) => {
  await page.goto('/en/')
  await page.getByRole('link', { name: 'Try AR' }).click()
  await expect(page).toHaveURL(/\/ar\/$/)
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US')
  await page.goto('/ja/guide/ar')
  await page.getByRole('link', { name: 'デバイスシミュレーターを開く' }).click()
  await expect(page.locator('html')).toHaveAttribute('lang', 'ja-JP')
  await page.goto('/')
  await page.getByRole('link', { name: '体验 AR' }).click()
  await expect(page.locator('html')).toHaveAttribute('lang', 'zh-CN')
})
