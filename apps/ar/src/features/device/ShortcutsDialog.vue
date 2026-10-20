<script setup lang="ts">
import type { MessageKey } from '../../i18n/locale'
import type { ShortcutId } from './shortcuts'
import { AgmButton, AgmDialog, AgmSwitch } from 'augma'
import { computed, shallowRef, watch } from 'vue'
import { t } from '../../i18n/locale'
import { checkChord, chordFromEvent, chordLabel, formatChord, shortcutGroups, shortcutLabels } from './shortcuts'

const props = defineProps<{
  bindings: Record<ShortcutId, string | null>
  /** Actions whose binding differs from the default. */
  customized: readonly ShortcutId[]
  /** Actions this browser cannot perform. */
  hidden: readonly ShortcutId[]
  mac: boolean
  /** Running inside the macOS app, whose menu adds ⇧⌘V for voice commands. */
  native: boolean
  storageAvailable: boolean
}>()
const emit = defineEmits<{ assign: [id: ShortcutId, chord: string | null], reset: [id: ShortcutId], resetAll: [] }>()
const open = defineModel<boolean>('open', { required: true })
const enabled = defineModel<boolean>('enabled', { required: true })

const groups = computed(() => shortcutGroups.map(group => ({ id: group.id, actions: group.actions.filter(id => !props.hidden.includes(id)) })))
/** Keys that are not customizable: standard dialog and panel keys, Reka's notification hotkey and the native menu. */
const fixed = computed<{ label: MessageKey, keys: string[] }[]>(() => [
  { label: 'shortcuts.fixed.close', keys: ['Esc'] },
  { label: 'shortcuts.fixed.move', keys: ['←', '↑', '→', '↓'] },
  { label: 'shortcuts.fixed.toast', keys: ['F8'] },
  ...props.native ? [{ label: 'shortcuts.fixed.nativeVoice' as const, keys: formatChord('Shift+Meta+v', true) }] : [],
])
const recording = shallowRef<ShortcutId | null>(null)
/** A chord another action uses, waiting for a second press to take it over. */
const pending = shallowRef<string | null>(null)
const status = shallowRef('')
// Set when a key press was recorded, so its keyup does not also click the focused button.
let swallowKeyUp = false

const label = (id: ShortcutId) => t(shortcutLabels[id])

function warning(id: ShortcutId) {
  const chord = props.bindings[id]
  const issue = chord ? checkChord(chord, props.mac) : null
  return issue?.level === 'warning' ? t(`shortcuts.warning.${issue.reason}`) : ''
}

function owner(chord: string, id: ShortcutId) {
  return (Object.keys(props.bindings) as ShortcutId[]).find(other => other !== id && props.bindings[other] === chord) ?? null
}

function toggle(event: MouseEvent, id: ShortcutId) {
  pending.value = null
  if (recording.value === id) {
    recording.value = null
    status.value = ''
    return
  }
  // Safari does not focus a button on pointer click; the button receives the keys being recorded.
  if (event.currentTarget instanceof HTMLElement)
    event.currentTarget.focus()
  recording.value = id
  status.value = t('shortcuts.recordingHint', { action: label(id) })
}

function finish(message: string) {
  recording.value = null
  pending.value = null
  status.value = message
}

function capture(event: KeyboardEvent, id: ShortcutId) {
  // Tab leaves the button, which ends recording.
  if (recording.value !== id || event.key === 'Tab')
    return
  event.preventDefault()
  // Keeps Escape from closing the dialog while recording.
  event.stopPropagation()
  swallowKeyUp = true
  if (event.repeat)
    return
  const bare = !event.ctrlKey && !event.altKey && !event.metaKey && !event.shiftKey
  if (event.key === 'Escape' && bare) {
    finish('')
    return
  }
  if ((event.key === 'Backspace' || event.key === 'Delete') && bare) {
    emit('assign', id, null)
    finish(t('shortcuts.cleared', { action: label(id) }))
    return
  }
  const chord = chordFromEvent(event)
  if (!chord)
    return
  const keys = chordLabel(chord, props.mac)
  const issue = checkChord(chord, props.mac)
  if (issue?.level === 'blocked') {
    pending.value = null
    status.value = t(`shortcuts.blocked.${issue.reason}`, { keys })
    return
  }
  const other = owner(chord, id)
  if (other && pending.value !== chord) {
    pending.value = chord
    status.value = t('shortcuts.taken', { keys, other: label(other), action: label(id) })
    return
  }
  emit('assign', id, chord)
  finish(other ? t('shortcuts.replaced', { action: label(id), keys, other: label(other) }) : t('shortcuts.saved', { action: label(id), keys }))
}

function release(event: KeyboardEvent) {
  if (!swallowKeyUp)
    return
  swallowKeyUp = false
  event.preventDefault()
}

function cancel(id: ShortcutId) {
  if (recording.value === id)
    finish('')
}

function reset(id: ShortcutId) {
  emit('reset', id)
  finish(t('shortcuts.restored', { action: label(id) }))
}

function resetAll() {
  emit('resetAll')
  finish(t('shortcuts.restoredAll'))
}

watch(open, () => finish(''))
</script>

<template>
  <AgmDialog v-model:open="open" :title="t('shortcuts.title')" :description="t('shortcuts.description')" :close-label="t('settings.closeDialog')">
    <div class="shortcut-sheet" :class="{ 'is-disabled': !enabled }">
      <AgmSwitch v-model="enabled" :label="t('shortcuts.enabled')" />
      <p v-if="!storageAvailable" class="shortcut-note">{{ t('shortcuts.storageUnavailable') }}</p>
      <section v-for="group in groups" :key="group.id" class="shortcut-group" :aria-labelledby="`shortcut-group-${group.id}`">
        <h3 :id="`shortcut-group-${group.id}`">{{ t(`shortcuts.group.${group.id}`) }}</h3>
        <ul>
          <li v-for="id in group.actions" :key="id" class="shortcut-row" :class="{ 'is-recording': recording === id }">
            <span class="shortcut-name">{{ label(id) }}</span>
            <span class="shortcut-keys">
              <template v-if="recording === id">{{ t('shortcuts.recording') }}</template>
              <template v-else-if="bindings[id]"><kbd v-for="key in formatChord(bindings[id], mac)" :key="key">{{ key }}</kbd></template>
              <template v-else>{{ t('shortcuts.unassigned') }}</template>
            </span>
            <span class="shortcut-actions">
              <button type="button" :aria-label="t('shortcuts.changeLabel', { action: label(id) })" :aria-pressed="recording === id" @click="toggle($event, id)" @keydown="capture($event, id)" @keyup="release" @blur="cancel(id)">{{ t('shortcuts.change') }}</button>
              <button v-if="customized.includes(id)" type="button" :aria-label="t('shortcuts.resetLabel', { action: label(id) })" @click="reset(id)">{{ t('shortcuts.reset') }}</button>
            </span>
            <p v-if="warning(id)" class="shortcut-warning">{{ warning(id) }}</p>
          </li>
          <template v-if="group.id === 'general'">
            <li v-for="item in fixed" :key="item.label" class="shortcut-row">
              <span class="shortcut-name">{{ t(item.label) }}</span>
              <span class="shortcut-keys"><kbd v-for="key in item.keys" :key="key">{{ key }}</kbd></span>
              <span class="shortcut-actions" />
            </li>
          </template>
        </ul>
      </section>
      <p class="shortcut-status" role="status">{{ status }}</p>
    </div>
    <template #footer>
      <AgmButton variant="outline" @click="resetAll">{{ t('shortcuts.resetAll') }}</AgmButton>
      <AgmButton @click="open = false">{{ t('shortcuts.done') }}</AgmButton>
    </template>
  </AgmDialog>
</template>

<style scoped>
.shortcut-sheet { display: grid; gap: 4px; }
.shortcut-sheet.is-disabled .shortcut-group { opacity: .6; }
.shortcut-group h3 { margin: 18px 0 4px; font-size: 12px; font-weight: 500; color: var(--agm-muted); }
.shortcut-group ul { margin: 0; padding: 0; list-style: none; }
.shortcut-row { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: 4px 10px; min-height: 40px; padding: 4px 0; border-bottom: 1px solid var(--agm-border); font-size: 13px; }
.shortcut-row:last-child { border-bottom: 0; }
.shortcut-keys { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 4px; color: var(--agm-muted); font-size: 12px; }
.is-recording .shortcut-keys { color: var(--agm-accent); }
/* System UI fonts carry ⌘⌥⇧⌃ at full size; most monospace fonts do not. */
kbd { min-width: 24px; padding: 1px 6px; border: 1px solid var(--agm-border); border-bottom-width: 2px; border-radius: 3px; background: var(--agm-surface); color: var(--agm-text); font: 500 12px/18px system-ui, sans-serif; text-align: center; }
/* A fixed width keeps every row's keys and Change button in line, with or without the Default button. */
.shortcut-actions { display: flex; gap: 2px; min-width: 8.5em; }
.shortcut-actions button { min-height: 32px; padding: 0 8px; border: 0; border-radius: 3px; background: transparent; color: var(--agm-text); font-size: 12px; cursor: pointer; }
.shortcut-actions button:hover, .shortcut-actions button[aria-pressed='true'] { background: rgb(255 255 255 / 14%); }
.shortcut-warning { grid-column: 1 / -1; margin: 0 0 4px; font-size: 11px; line-height: 1.6; color: var(--agm-muted); }
.shortcut-warning::before { content: '⚠ '; color: #ffd28a; }
.shortcut-note, .shortcut-status { margin: 8px 0 0; font-size: 12px; line-height: 1.7; color: var(--agm-muted); }
.shortcut-status:empty { margin: 0; }
@media (max-width: 480px) { .shortcut-row { grid-template-columns: minmax(0, 1fr) auto; } .shortcut-actions { grid-column: 1 / -1; justify-content: flex-end; min-width: 0; } .shortcut-actions:empty { display: none; } }
</style>
