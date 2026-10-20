import { shallowRef } from 'vue'

/** Where the browser keeps the user's DeepSeek key. The macOS app keeps its key in the Keychain instead. */
export const assistantKeyStorage = 'augma-deepseek-key'

function read(): string | null {
  try {
    return localStorage.getItem(assistantKeyStorage) || null
  }
  catch {
    return null
  }
}

/**
 * The user's own DeepSeek API key for the web demo, kept only in this browser.
 *
 * @returns The current `key`, plus `save` and `remove`
 */
export function useAssistantKey() {
  const key = shallowRef(read())

  /** @returns `false` when the key is blank or storage is unavailable */
  function save(value: string): boolean {
    const next = value.trim()
    if (!next)
      return false
    try {
      localStorage.setItem(assistantKeyStorage, next)
    }
    catch {
      return false
    }
    key.value = next
    return true
  }

  function remove() {
    try {
      localStorage.removeItem(assistantKeyStorage)
    }
    catch {}
    key.value = null
  }

  return { key, save, remove }
}
