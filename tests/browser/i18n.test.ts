import { expect, test } from '@playwright/test'

interface Spoken { text: string, lang: string }

// Replace speech synthesis so tests can read what would be spoken without audio output.
async function recordSpeech(page: import('@playwright/test').Page) {
  await page.addInitScript(() => {
    const spoken: Spoken[] = []
    Object.defineProperty(window, '__spoken', { value: spoken })
    class FakeUtterance {
      lang = ''
      voice: unknown = null
      constructor(public text: string) {}
    }
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { value: FakeUtterance, configurable: true })
    Object.defineProperty(window, 'speechSynthesis', {
      configurable: true,
      value: {
        speak: (utterance: FakeUtterance) => spoken.push({ text: utterance.text, lang: utterance.lang }),
        cancel: () => {},
        getVoices: () => [],
        addEventListener: () => {},
        removeEventListener: () => {},
      },
    })
  })
}

const spoken = (page: import('@playwright/test').Page) => page.evaluate(() => (window as Window & { __spoken?: Spoken[] }).__spoken ?? [])

test.describe('English browser', () => {
  test.use({ locale: 'en-US' })

  test('follows the browser language and speaks command results', async ({ page }) => {
    await recordSpeech(page)
    await page.goto('/ar/')
    await expect(page.locator('html')).toHaveAttribute('lang', 'en-US')
    await expect(page).toHaveTitle('AR Demo · Augma')
    await page.getByRole('button', { name: 'Voice commands' }).click()
    await page.getByRole('textbox', { name: 'Type a command' }).fill('open the map')
    await page.getByRole('button', { name: 'Run', exact: true }).click()
    await expect(page.getByRole('heading', { name: 'Navigation' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Start simulated navigation' })).toBeVisible()
    await expect.poll(() => spoken(page)).toEqual([{ text: 'Simulated map opened', lang: 'en-US' }])
  })

  test('names the dialog and toast controls in English', async ({ page }) => {
    await page.goto('/ar/')
    await page.getByRole('button', { name: 'System menu' }).click()
    await page.getByRole('button', { name: 'Settings' }).click()
    await page.getByRole('button', { name: 'Restore defaults', exact: true }).click()
    await expect(page.getByRole('dialog', { name: 'Restore defaults' })).toBeVisible()
    await page.getByRole('button', { name: 'Close dialog' }).click()
    await expect(page.getByRole('dialog')).toBeHidden()

    await page.getByRole('button', { name: 'Restore defaults', exact: true }).click()
    await page.getByRole('button', { name: 'Restore', exact: true }).click()
    await expect(page.getByRole('region', { name: 'Notifications (F8)' })).toBeAttached()
    await expect(page.getByRole('button', { name: 'Close notification' })).toBeVisible()
  })
})

test('switches language from settings, keeps it after reload and can mute spoken feedback', async ({ page }) => {
  await recordSpeech(page)
  await page.goto('/ar/')
  await page.getByRole('button', { name: '系统菜单' }).click()
  await page.getByRole('button', { name: '设置' }).click()
  await page.getByRole('combobox', { name: '语言' }).click()
  await page.getByRole('option', { name: '日本語' }).click()
  await expect(page.getByRole('heading', { name: '設定' })).toBeVisible()
  await expect(page.locator('html')).toHaveAttribute('lang', 'ja-JP')
  await expect(page.getByRole('switch', { name: '音声読み上げ' })).toBeChecked()

  await page.reload()
  await page.getByRole('button', { name: '音声コマンド' }).click()
  await page.getByRole('button', { name: 'ダークモードにして' }).click()
  await expect(page.locator('.ar-app')).toHaveClass(/is-dark/)
  await expect.poll(() => spoken(page)).toEqual([{ text: 'ダークビューをオンにしました', lang: 'ja-JP' }])

  await page.getByRole('button', { name: 'システムメニュー' }).click()
  await page.getByRole('button', { name: '設定' }).click()
  await page.getByRole('switch', { name: '音声読み上げ' }).click()
  await page.getByRole('button', { name: '音声コマンド' }).click()
  await page.getByRole('textbox', { name: 'コマンドを入力' }).fill('天気を表示して')
  await page.getByRole('button', { name: '実行', exact: true }).click()
  await expect(page.getByRole('heading', { name: '天気' })).toBeVisible()
  expect(await spoken(page)).toHaveLength(1)
})

test('sends the active language to the native speech recognizer', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('augma-locale', 'ja-JP')
    const actions: unknown[] = []
    Object.defineProperty(window, '__speechActions', { value: actions })
    Object.defineProperty(window, 'webkit', {
      value: { messageHandlers: { speechCommand: { postMessage: (action: unknown) => actions.push(action) } } },
    })
  })
  await page.goto('/ar/')
  await page.getByRole('button', { name: '音声コマンド' }).click()
  await page.getByRole('button', { name: '音声認識を開始' }).click()
  await expect.poll(() => page.evaluate(() => (window as Window & { __speechActions?: unknown[] }).__speechActions?.at(-1))).toEqual({ action: 'start', locale: 'ja-JP' })
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'error', code: 'microphoneStart', text: 'busy' } })))
  await expect(page.getByText('マイクを起動できません：busy')).toBeVisible()
  await page.getByRole('button', { name: '音声認識を開始' }).click()
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('augma:speech', { detail: { type: 'final', text: '空間をスキャンして' } })))
  await expect(page.getByRole('progressbar', { name: '空間スキャン' })).toBeVisible()
})
