import type { Locale } from '../../i18n/locale'
import type { VoiceCommand } from './voiceCommands'
import { isVoiceCommand } from './voiceCommands'

/** A chat message in the shape the DeepSeek Chat Completions API takes. */
export interface AssistantMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

/** What the assistant decided: a spoken reply, or one demo command whose result the device announces itself. */
export interface AssistantAnswer {
  reply: string
  command: VoiceCommand | null
}

/** One earlier exchange, replayed so follow-up questions keep their context. */
export interface AssistantTurn extends AssistantAnswer {
  question: string
}

/** Error codes the page translates under `speech.error.*`; the macOS app reports the same codes. */
export type AssistantErrorCode
  = | 'deepseekNotConfigured' | 'deepseekInvalidInput' | 'deepseekInvalidKey' | 'deepseekInsufficientBalance'
    | 'deepseekRateLimited' | 'deepseekInvalidResponse' | 'deepseekHttp' | 'deepseekRequest'

const errorCodes: readonly AssistantErrorCode[] = [
  'deepseekNotConfigured',
  'deepseekInvalidInput',
  'deepseekInvalidKey',
  'deepseekInsufficientBalance',
  'deepseekRateLimited',
  'deepseekInvalidResponse',
  'deepseekHttp',
  'deepseekRequest',
]

export function isAssistantErrorCode(value: unknown): value is AssistantErrorCode {
  return typeof value === 'string' && (errorCodes as readonly string[]).includes(value)
}

export class AssistantError extends Error {
  constructor(readonly code: AssistantErrorCode, readonly detail = '') {
    super(detail ? `${code}: ${detail}` : code)
    this.name = 'AssistantError'
  }
}

/** Questions longer than this are rejected before anything is sent. */
export const maxQuestionLength = 500
/** Earlier exchanges sent along with a question. */
export const historyLimit = 4
const maxReplyLength = 600

const languages: Record<Locale, string> = { 'zh-CN': 'Simplified Chinese', 'en-US': 'English', 'ja-JP': 'Japanese' }

function systemPrompt(locale: Locale) {
  return `You are Augma, the voice assistant of a simulated AR headset DEMO running in a web page. Always answer in ${languages[locale]}.
Output only a JSON object: {"reply": string, "command": string or null}.
Set command only when the user explicitly asks for one of these demo actions, otherwise null:
- map: open the simulated map
- scan: scan the simulated space
- audio / audioPause: play / pause the demo soundscape
- hide / show: hide / show the HUD
- weather: open the demo weather panel (sample data, not a real forecast)
- notifications / settings: open that panel
- camera: open the camera panel (it never turns the camera on)
- dark / light: switch the theme
- routeStart / routeNext / routeStop: start, advance or end the simulated route
When you set a command, the device announces the result itself, so set reply to "".
Otherwise reply is what you say aloud: at most two short sentences of plain text, with no Markdown, lists, emoji or links.
You have no internet, real-time data, location, files, apps or messages; places, weather and notifications in this demo are simulated. If asked for something you cannot do, say so briefly and suggest what the demo can do. Never claim to have done anything else.`
}

/**
 * Build the messages for one question: the system prompt, recent exchanges, then the question.
 *
 * @param question - What the user said or typed
 * @param locale - The UI language the reply must use
 * @param history - Earlier exchanges, oldest first; only the last {@link historyLimit} are sent
 * @returns Messages for the Chat Completions API
 */
export function assistantMessages(question: string, locale: Locale, history: readonly AssistantTurn[] = []): AssistantMessage[] {
  const text = question.trim()
  if (!text || text.length > maxQuestionLength)
    throw new AssistantError('deepseekInvalidInput')
  return [
    { role: 'system', content: systemPrompt(locale) },
    ...history.slice(-historyLimit).flatMap(turn => [
      { role: 'user', content: turn.question } as const,
      { role: 'assistant', content: JSON.stringify({ reply: turn.reply, command: turn.command }) } as const,
    ]),
    { role: 'user', content: text },
  ]
}

/**
 * Read the assistant's JSON answer and keep any command on the demo allowlist.
 *
 * @param content - The message content the model returned
 * @returns The reply and the command, if any
 * @throws {AssistantError} `deepseekInvalidResponse` for anything but `{"reply", "command"}` with an allowed command
 */
export function parseAssistantAnswer(content: string): AssistantAnswer {
  let body: unknown
  try {
    body = JSON.parse(content)
  }
  catch {
    throw new AssistantError('deepseekInvalidResponse')
  }
  if (!body || typeof body !== 'object' || Array.isArray(body))
    throw new AssistantError('deepseekInvalidResponse')
  const { reply, command, ...extra } = body as Record<string, unknown>
  if (Object.keys(extra).length || typeof reply !== 'string' || (command !== null && !isVoiceCommand(command)))
    throw new AssistantError('deepseekInvalidResponse')
  const text = reply.trim().slice(0, maxReplyLength)
  if (!command && !text)
    throw new AssistantError('deepseekInvalidResponse')
  return { reply: text, command }
}

/**
 * The request body. The macOS app pins the same model and limits in `DeepSeekClient.swift`.
 *
 * @param messages - Messages from {@link assistantMessages}
 */
export function deepSeekBody(messages: readonly AssistantMessage[]) {
  return {
    model: 'deepseek-flash',
    thinking: { type: 'disabled' },
    response_format: { type: 'json_object' },
    max_tokens: 300,
    messages,
  }
}

/**
 * Take the message content out of a Chat Completions response.
 *
 * @param data - The parsed response body
 * @returns The content of the first choice
 * @throws {AssistantError} `deepseekInvalidResponse` when the reply was cut short or has no text
 */
export function completionContent(data: unknown): string {
  const choice = (data as { choices?: { finish_reason?: unknown, message?: { content?: unknown } }[] } | null)?.choices?.[0]
  const content = choice?.message?.content
  if (choice?.finish_reason !== 'stop' || typeof content !== 'string' || !content)
    throw new AssistantError('deepseekInvalidResponse')
  return content
}

const endpoint = 'https://api.deepseek.com/chat/completions'

/**
 * Ask DeepSeek straight from the browser with the user's own key. The macOS app sends the request natively instead.
 *
 * @param messages - Messages from {@link assistantMessages}
 * @param apiKey - The user's DeepSeek API key
 * @param signal - Aborts the request when the user cancels
 * @returns The model's message content, for {@link parseAssistantAnswer}
 * @throws {AssistantError} With the code the page shows; an aborted request rethrows the abort error
 */
export async function requestDeepSeek(messages: readonly AssistantMessage[], apiKey: string, signal?: AbortSignal): Promise<string> {
  const timeout = AbortSignal.timeout(20_000)
  let response: Response
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
      body: JSON.stringify(deepSeekBody(messages)),
      signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
    })
  }
  catch (error) {
    if (signal?.aborted)
      throw error
    throw new AssistantError('deepseekRequest', timeout.aborted ? 'timeout' : error instanceof Error ? error.message : String(error))
  }
  switch (response.status) {
    case 200:
      break
    case 401:
      throw new AssistantError('deepseekInvalidKey')
    case 402:
      throw new AssistantError('deepseekInsufficientBalance')
    case 429:
      throw new AssistantError('deepseekRateLimited')
    default:
      throw new AssistantError('deepseekHttp', String(response.status))
  }
  let data: unknown
  try {
    data = await response.json()
  }
  catch {
    throw new AssistantError('deepseekInvalidResponse')
  }
  return completionContent(data)
}
