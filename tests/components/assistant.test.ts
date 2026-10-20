import { afterEach, describe, expect, it, vi } from 'vitest'
import { AssistantError, assistantMessages, completionContent, deepSeekBody, parseAssistantAnswer, requestDeepSeek } from '../../apps/ar/src/features/device/assistant'
import { createBrowserRecorder } from '../../apps/ar/src/features/device/browserSpeech'

afterEach(() => {
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

function completion(content: string, finish = 'stop') {
  return { choices: [{ finish_reason: finish, message: { content } }] }
}

describe('deepSeek assistant', () => {
  it('asks in the UI language and replays only the last exchanges', () => {
    const history = Array.from({ length: 6 }, (_, index) => ({ question: `q${index}`, reply: `a${index}`, command: null }))
    const messages = assistantMessages('  现在几点  ', 'ja-JP', history)
    expect(messages[0]).toMatchObject({ role: 'system' })
    expect(messages[0]!.content).toContain('Always answer in Japanese')
    expect(messages.slice(1, -1).map(message => message.content)).toEqual([
      'q2',
      '{"reply":"a2","command":null}',
      'q3',
      '{"reply":"a3","command":null}',
      'q4',
      '{"reply":"a4","command":null}',
      'q5',
      '{"reply":"a5","command":null}',
    ])
    expect(messages.at(-1)).toEqual({ role: 'user', content: '现在几点' })
    expect(() => assistantMessages(' ', 'zh-CN')).toThrow(AssistantError)
    expect(() => assistantMessages('x'.repeat(501), 'zh-CN')).toThrow(AssistantError)
  })

  it('accepts a spoken reply or one allowed command', () => {
    expect(parseAssistantAnswer('{"reply":" 这是演示天气。 ","command":null}')).toEqual({ reply: '这是演示天气。', command: null })
    expect(parseAssistantAnswer('{"reply":"","command":"weather"}')).toEqual({ reply: '', command: 'weather' })
  })

  it.each([
    'not json',
    '[]',
    '{"reply":"","command":null}',
    '{"reply":"ok","command":"deleteFiles"}',
    '{"reply":"ok","command":null,"path":"/tmp"}',
    '{"reply":1,"command":null}',
    '{"command":"map"}',
  ])('rejects %s', (content) => {
    expect(() => parseAssistantAnswer(content)).toThrow(expect.objectContaining({ code: 'deepseekInvalidResponse' }))
  })

  it('pins the model and rejects truncated completions', () => {
    expect(deepSeekBody([])).toMatchObject({ model: 'deepseek-flash', thinking: { type: 'disabled' }, response_format: { type: 'json_object' } })
    expect(completionContent(completion('{"reply":"hi","command":null}'))).toBe('{"reply":"hi","command":null}')
    expect(() => completionContent(completion('{"reply":"hi"', 'length'))).toThrow(AssistantError)
    expect(() => completionContent({ choices: [] })).toThrow(AssistantError)
  })

  it('calls DeepSeek with the key and maps failures to codes the page translates', async () => {
    const fetch = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify(completion('{"reply":"hi","command":null}'))))
      .mockResolvedValueOnce(new Response('', { status: 401 }))
      .mockResolvedValueOnce(new Response('', { status: 402 }))
      .mockResolvedValueOnce(new Response('', { status: 429 }))
      .mockResolvedValueOnce(new Response('', { status: 503 }))
      .mockRejectedValueOnce(new TypeError('Failed to fetch'))
    vi.stubGlobal('fetch', fetch)
    const messages = assistantMessages('hello', 'en-US')
    await expect(requestDeepSeek(messages, 'sk-test')).resolves.toBe('{"reply":"hi","command":null}')
    const [url, init] = fetch.mock.calls[0]!
    expect(url).toBe('https://api.deepseek.com/chat/completions')
    expect(init.headers.Authorization).toBe('Bearer sk-test')
    expect(JSON.parse(init.body).messages).toEqual(messages)
    await expect(requestDeepSeek(messages, 'sk-test')).rejects.toMatchObject({ code: 'deepseekInvalidKey' })
    await expect(requestDeepSeek(messages, 'sk-test')).rejects.toMatchObject({ code: 'deepseekInsufficientBalance' })
    await expect(requestDeepSeek(messages, 'sk-test')).rejects.toMatchObject({ code: 'deepseekRateLimited' })
    await expect(requestDeepSeek(messages, 'sk-test')).rejects.toMatchObject({ code: 'deepseekHttp', detail: '503' })
    await expect(requestDeepSeek(messages, 'sk-test')).rejects.toMatchObject({ code: 'deepseekRequest', detail: 'Failed to fetch' })
  })
})

describe('browser speech recorder', () => {
  class FakeRecognition {
    static last: FakeRecognition
    lang = ''
    continuous = false
    interimResults = false
    onstart: (() => void) | null = null
    onresult: ((event: { results: { transcript: string }[][] }) => void) | null = null
    onerror: ((event: { error: string }) => void) | null = null
    onend: (() => void) | null = null
    start = vi.fn(() => this.onstart?.())
    stop = vi.fn(() => this.onend?.())
    abort = vi.fn(() => {
      this.onerror?.({ error: 'aborted' })
      this.onend?.()
    })

    constructor() {
      FakeRecognition.last = this
    }
  }

  it('is unavailable without the Web Speech API', () => {
    expect(createBrowserRecorder(vi.fn())).toBeNull()
  })

  it('streams partial text and finishes with the transcript', () => {
    vi.stubGlobal('webkitSpeechRecognition', FakeRecognition)
    const emit = vi.fn()
    const recorder = createBrowserRecorder(emit)!
    recorder.start('ja-JP')
    const recognition = FakeRecognition.last
    expect(recognition).toMatchObject({ lang: 'ja-JP', continuous: true, interimResults: true })
    recognition.onresult?.({ results: [[{ transcript: '地図を' }], [{ transcript: '開いて' }]] })
    recorder.stop()
    expect(emit.mock.calls.map(([detail]) => detail)).toEqual([
      { type: 'listening' },
      { type: 'partial', text: '地図を開いて' },
      { type: 'processing' },
      { type: 'final', text: '地図を開いて' },
    ])
  })

  it('stops after 12 seconds, reports permission errors and stays quiet when cancelled', () => {
    vi.useFakeTimers()
    vi.stubGlobal('SpeechRecognition', FakeRecognition)
    const emit = vi.fn()
    const recorder = createBrowserRecorder(emit)!
    recorder.start('en-US')
    vi.advanceTimersByTime(12_000)
    expect(FakeRecognition.last.stop).toHaveBeenCalled()

    emit.mockClear()
    recorder.start('en-US')
    FakeRecognition.last.onerror?.({ error: 'not-allowed' })
    FakeRecognition.last.onend?.()
    expect(emit).toHaveBeenLastCalledWith({ type: 'error', code: 'browserMicrophone' })

    emit.mockClear()
    recorder.start('en-US')
    recorder.cancel()
    expect(emit.mock.calls).toEqual([[{ type: 'listening' }]])
  })
})
