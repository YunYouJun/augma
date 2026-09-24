import { expect, test } from '@playwright/test'

test('native speech bridge runs a recognized command and rejects unrelated speech', async ({ page }) => {
  await page.addInitScript(() => {
    const actions: string[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: string) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: string[] }).__speechActions?.filter(action => action !== 'config'))).toEqual(['start'])
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'listening' } })))
  await page.getByRole('button', { name: '结束并执行' }).click()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: string[] }).__speechActions?.filter(action => action !== 'config'))).toEqual(['start', 'stop'])
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '今天天气怎么样' } })))
  await expect(page.getByText('未匹配到指令：今天天气怎么样')).toBeVisible()
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()

  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'listening' } })))
  await page.getByRole('button', { name: '关闭语音指令' }).click()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: string[] }).__speechActions?.filter(action => action !== 'config'))).toEqual(['start', 'stop', 'start', 'cancel'])

  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '扫描空间' } })))
  await expect(page.getByRole('heading', { name: '空间' })).toBeVisible()
  await expect(page.getByRole('progressbar', { name: '空间扫描' })).toBeVisible()
})

test('shortcut controls recording and expanded commands operate the demo', async ({ page }) => {
  await page.addInitScript(() => {
    const actions: string[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: string) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.evaluate(() => window.dispatchEvent(new Event('augma:toggle-speech')))
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: string[] }).__speechActions?.filter(action => action !== 'config'))).toEqual(['start'])
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'listening' } })))
  await page.evaluate(() => window.dispatchEvent(new Event('augma:toggle-speech')))
  await expect(page.getByRole('button', { name: '正在识别…' })).toBeDisabled()
  await page.evaluate(() => window.dispatchEvent(new Event('augma:toggle-speech')))
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: string[] }).__speechActions?.filter(action => action !== 'config'))).toEqual(['start', 'stop', 'cancel'])
  await expect(page.getByRole('button', { name: '开始语音识别' })).toBeVisible()

  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.getByRole('button', { name: '取消录音' }).click()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: string[] }).__speechActions?.filter(action => action !== 'config'))).toEqual(['start', 'stop', 'cancel', 'start', 'cancel'])

  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '打开天气' } })))
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'cancelled' } })))
  await expect(page.getByText('录音已取消。')).toBeVisible()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '打开天气' } })))
  await expect(page.getByRole('heading', { name: '天气' })).toBeVisible()
  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '开启深色视界' } })))
  await expect(page.locator('.ar-app')).toHaveClass(/is-dark/)
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '开始导航' } })))
  await expect(page.getByRole('progressbar', { name: '路线进度' })).toBeVisible()
})

test('typed commands work locally and optional DeepSeek results stay on the command allowlist', async ({ page }) => {
  await page.addInitScript(() => {
    const actions: unknown[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: unknown) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('textbox', { name: '输入指令' }).fill('打开天气')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByRole('heading', { name: '天气' })).toBeVisible()
  expect(await page.evaluate(() => (window as Window & { __speechActions?: unknown[] }).__speechActions?.some(action => typeof action === 'object'))).toBe(false)

  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'config', enabled: true } })))
  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('textbox', { name: '输入指令' }).fill('麻烦调出天气面板')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByRole('button', { name: '正在理解指令…' })).toBeDisabled()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: unknown[] }).__speechActions?.at(-1))).toEqual({ action: 'interpret', text: '麻烦调出天气面板' })
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'interpreted', text: 'deleteFiles' } })))
  await expect(page.getByText('未匹配到指令：麻烦调出天气面板')).toBeVisible()

  await page.getByRole('button', { name: '执行' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'interpreted', text: 'weather' } })))
  await expect(page.getByRole('heading', { name: '天气' })).toBeVisible()

  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('textbox', { name: '输入指令' }).fill('麻烦调出天气面板')
  await page.getByRole('button', { name: '执行' }).click()
  await page.getByRole('button', { name: '取消理解' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'interpreted', text: 'weather' } })))
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()
  await expect(page.getByText('已取消理解。')).toBeVisible()
})
