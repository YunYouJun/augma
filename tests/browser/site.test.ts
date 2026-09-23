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
  await expect(dialog.getByRole('slider')).toHaveAttribute(
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
  expect(contract.components).toHaveLength(12)
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
