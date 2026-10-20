import type { Page } from '@playwright/test'
import { expect, test } from '@playwright/test'

// Native bridge messages, with the locale-carrying start message reduced to its action name.
function speechActions(page: Page) {
  return page.evaluate(() => (window as Window & { __speechActions?: unknown[] }).__speechActions?.map(action => typeof action === 'string' ? action : (action as { action: string }).action).filter(action => action !== 'config'))
}

test('native speech bridge runs a recognized command and rejects unrelated speech', async ({ page }) => {
  await page.addInitScript(() => {
    const actions: unknown[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: unknown) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await expect.poll(() => speechActions(page)).toEqual(['start'])
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'listening' } })))
  await page.getByRole('button', { name: '结束并执行' }).click()
  await expect.poll(() => speechActions(page)).toEqual(['start', 'stop'])
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '今天天气怎么样' } })))
  await expect(page.getByText('未匹配到指令：今天天气怎么样')).toBeVisible()
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()

  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'listening' } })))
  await page.getByRole('button', { name: '关闭语音指令' }).click()
  await expect.poll(() => speechActions(page)).toEqual(['start', 'stop', 'start', 'cancel'])

  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '扫描空间' } })))
  await expect(page.getByRole('heading', { name: '空间' })).toBeVisible()
  await expect(page.getByRole('progressbar', { name: '空间扫描' })).toBeVisible()
})

test('shortcut controls recording and expanded commands operate the demo', async ({ page }) => {
  await page.addInitScript(() => {
    const actions: unknown[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: unknown) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.evaluate(() => window.dispatchEvent(new Event('augma:toggle-speech')))
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()
  await expect.poll(() => speechActions(page)).toEqual(['start'])
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'listening' } })))
  await page.evaluate(() => window.dispatchEvent(new Event('augma:toggle-speech')))
  await expect(page.getByRole('button', { name: '正在识别…' })).toBeDisabled()
  await page.evaluate(() => window.dispatchEvent(new Event('augma:toggle-speech')))
  await expect.poll(() => speechActions(page)).toEqual(['start', 'stop', 'cancel'])
  await expect(page.getByRole('button', { name: '开始语音识别' })).toBeVisible()

  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.getByRole('button', { name: '取消录音' }).click()
  await expect.poll(() => speechActions(page)).toEqual(['start', 'stop', 'cancel', 'start', 'cancel'])

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

// The last assistant request the page sent through the native bridge.
function lastInterpret(page: Page) {
  return page.evaluate(() => (window as Window & { __speechActions?: unknown[] }).__speechActions?.filter(action => typeof action === 'object' && (action as { action: string }).action === 'interpret').at(-1) as { messages: { role: string, content: string }[] } | undefined)
}

function interpreted(page: Page, content: object) {
  return page.evaluate(text => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'interpreted', text } })), JSON.stringify(content))
}

test('typed commands work locally and the native DeepSeek assistant answers or runs allowed commands', async ({ page }) => {
  await page.addInitScript(() => {
    const actions: unknown[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: unknown) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '语音指令' }).click()
  await expect(page.getByText('可在 Augma 设置中开启 DeepSeek 助手')).toBeVisible()
  await page.getByRole('textbox', { name: '输入指令' }).fill('打开天气')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByRole('heading', { name: '天气' })).toBeVisible()
  expect(await page.evaluate(() => (window as Window & { __speechActions?: unknown[] }).__speechActions?.some(action => typeof action === 'object' && (action as { action: string }).action === 'interpret'))).toBe(false)

  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'config', enabled: true } })))
  await page.getByRole('button', { name: '语音指令' }).click()
  await expect(page.getByText('其他说法和问题会交给 DeepSeek 助手回答。')).toBeVisible()
  await page.getByRole('textbox', { name: '输入指令' }).fill('麻烦调出天气面板')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByRole('button', { name: '正在理解指令…' })).toBeDisabled()
  await expect.poll(async () => (await lastInterpret(page))?.messages.at(-1)).toEqual({ role: 'user', content: '麻烦调出天气面板' })
  expect((await lastInterpret(page))?.messages[0]?.role).toBe('system')
  await interpreted(page, { reply: '', command: 'deleteFiles' })
  await expect(page.getByText('DeepSeek 未返回可用的回答。')).toBeVisible()

  await page.getByRole('button', { name: '执行' }).click()
  await interpreted(page, { reply: '', command: 'weather' })
  await expect(page.getByRole('heading', { name: '天气' })).toBeVisible()

  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('textbox', { name: '输入指令' }).fill('天气是实时的吗')
  await page.getByRole('button', { name: '执行' }).click()
  await interpreted(page, { reply: '那是演示数据，不是实时天气。', command: null })
  await expect(page.getByText('Augma：那是演示数据，不是实时天气。')).toBeVisible()
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()

  // Follow-up questions carry the earlier exchanges.
  await page.getByRole('textbox', { name: '输入指令' }).fill('那导航呢')
  await page.getByRole('button', { name: '执行' }).click()
  await expect.poll(async () => (await lastInterpret(page))?.messages.map(message => message.role)).toEqual(['system', 'user', 'assistant', 'user', 'assistant', 'user'])
  expect((await lastInterpret(page))?.messages[4]?.content).toBe('{"reply":"那是演示数据，不是实时天气。","command":null}')
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'error', code: 'deepseekInvalidKey' } })))
  await expect(page.getByText('DeepSeek 密钥无效，请在 Augma 设置中更新。')).toBeVisible()

  await page.getByRole('textbox', { name: '输入指令' }).fill('麻烦调出天气面板')
  await page.getByRole('button', { name: '执行' }).click()
  await page.getByRole('button', { name: '取消理解' }).click()
  await interpreted(page, { reply: '', command: 'weather' })
  await expect(page.getByRole('heading', { name: '语音指令' })).toBeVisible()
  await expect(page.getByText('已取消理解。')).toBeVisible()
})

test('web demo asks DeepSeek with a key kept in this browser', async ({ page }) => {
  const requests: { authorization?: string, messages: { role: string, content: string }[] }[] = []
  await page.route('https://api.deepseek.com/chat/completions', async (route) => {
    const request = route.request()
    if (request.method() === 'OPTIONS')
      return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': 'authorization,content-type', 'access-control-allow-methods': 'POST' } })
    const { messages } = request.postDataJSON() as { messages: { role: string, content: string }[] }
    requests.push({ authorization: await request.headerValue('authorization') ?? undefined, messages })
    const question = messages.at(-1)!.content
    const headers = { 'access-control-allow-origin': '*' }
    if (question === '换一个密钥')
      return route.fulfill({ status: 401, headers, body: '' })
    const content = question.includes('地图')
      ? { reply: '', command: 'map' }
      : { reply: '这是演示设备，查不到实时天气。', command: null }
    return route.fulfill({ headers, json: { choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(content) } }] } })
  })
  // Record what the system voice would read instead of playing audio.
  await page.addInitScript(() => {
    const spoken: string[] = []
    Object.defineProperty(window, '__spoken', { value: spoken })
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true, value: class { lang = ''; voice: unknown = null; constructor(public text: string) {} } })
    Object.defineProperty(window, 'speechSynthesis', {
      configurable: true,
      value: { speak: (utterance: { text: string }) => spoken.push(utterance.text), cancel: () => {}, getVoices: () => [], addEventListener: () => {}, removeEventListener: () => {} },
    })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '语音指令' }).click()
  await expect(page.getByText('在「设置」中填写 DeepSeek API Key 后，可以向助手提问。')).toBeVisible()
  await page.getByRole('textbox', { name: '输入指令' }).fill('今天会下雨吗')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByText('未匹配到指令：今天会下雨吗')).toBeVisible()
  expect(requests).toHaveLength(0)

  await page.getByRole('button', { name: '系统菜单', exact: true }).click()
  await page.getByRole('button', { name: '设置', exact: true }).click()
  await page.getByLabel('DeepSeek API Key').fill('sk-test')
  await page.getByRole('button', { name: '保存', exact: true }).click()
  await expect(page.getByText('密钥已保存，可以在语音指令中向助手提问。')).toBeVisible()
  expect(await page.evaluate(() => localStorage.getItem('augma-deepseek-key'))).toBe('sk-test')

  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('textbox', { name: '输入指令' }).fill('今天会下雨吗')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByText('Augma：这是演示设备，查不到实时天气。')).toBeVisible()
  await expect.poll(() => page.evaluate(() => (window as Window & { __spoken?: string[] }).__spoken?.at(-1))).toBe('这是演示设备，查不到实时天气。')
  expect(requests.at(-1)).toMatchObject({ authorization: 'Bearer sk-test' })
  expect(requests.at(-1)!.messages.at(-1)).toEqual({ role: 'user', content: '今天会下雨吗' })

  await page.getByRole('textbox', { name: '输入指令' }).fill('换一个密钥')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByText('DeepSeek 密钥无效，请在 Augma 设置中更新。')).toBeVisible()

  await page.getByRole('textbox', { name: '输入指令' }).fill('帮我看看地图在哪')
  await page.getByRole('button', { name: '执行' }).click()
  await expect(page.getByRole('heading', { name: '导航' })).toBeVisible()
  // A command's result is announced by the device, not by the model.
  await expect.poll(() => page.evaluate(() => (window as Window & { __spoken?: string[] }).__spoken?.at(-1))).toBe('已打开模拟地图')

  await page.getByRole('button', { name: '系统菜单', exact: true }).click()
  await page.getByRole('button', { name: '设置', exact: true }).click()
  await page.getByRole('button', { name: '删除密钥' }).click()
  await expect(page.getByLabel('DeepSeek API Key')).toBeVisible()
  expect(await page.evaluate(() => localStorage.getItem('augma-deepseek-key'))).toBeNull()
})

test('web demo records with the browser speech recognizer when there is no native bridge', async ({ page }) => {
  await page.addInitScript(() => {
    class FakeRecognition {
      lang = ''
      continuous = false
      interimResults = false
      onstart: (() => void) | null = null
      onresult: ((event: { results: { transcript: string }[][] }) => void) | null = null
      onerror: ((event: { error: string }) => void) | null = null
      onend: (() => void) | null = null
      start() {
        Object.defineProperty(window, '__recognition', { value: this, configurable: true })
        this.onstart?.()
      }

      stop() {
        this.onend?.()
      }

      abort() {
        this.onerror?.({ error: 'aborted' })
        this.onend?.()
      }
    }
    Object.defineProperty(window, 'SpeechRecognition', { value: FakeRecognition, configurable: true })
    Object.defineProperty(window, 'webkitSpeechRecognition', { value: FakeRecognition, configurable: true })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '语音指令' }).click()
  await expect(page.getByText('语音识别由浏览器提供')).toBeVisible()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  expect(await page.evaluate(() => (window as Window & { __recognition?: { lang: string } }).__recognition?.lang)).toBe('zh-CN')
  await page.evaluate(() => (window as Window & { __recognition?: { onresult: (event: unknown) => void } }).__recognition?.onresult({ results: [[{ transcript: '扫描' }], [{ transcript: '空间' }]] }))
  await expect(page.getByText('你：扫描空间')).toBeVisible()
  await page.getByRole('button', { name: '结束并执行' }).click()
  await expect(page.getByRole('progressbar', { name: '空间扫描' })).toBeVisible()

  await page.getByRole('button', { name: '语音指令' }).click()
  await page.getByRole('button', { name: '开始语音识别' }).click()
  await page.evaluate(() => {
    const recognition = (window as Window & { __recognition?: { onerror: (event: unknown) => void, onend: () => void } }).__recognition
    recognition?.onerror({ error: 'not-allowed' })
    recognition?.onend()
  })
  await expect(page.getByText('请允许此页面使用麦克风。')).toBeVisible()
})
