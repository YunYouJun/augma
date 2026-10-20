<script setup lang="ts">
import type { Locale } from '../../i18n/locale'
import { AgmButton, AgmDialog, AgmInput, AgmSelect, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'
import { localeNames, locales, resolveLocale, t } from '../../i18n/locale'

defineProps<{
  storageAvailable: boolean
  reducedMotion: boolean
  locale: Locale
  speechFeedbackSupported: boolean
  /** The macOS app configures DeepSeek in its own settings window and keeps the key in the Keychain. */
  assistantNative: boolean
  assistantReady: boolean
}>()
const emit = defineEmits<{ reset: [], locale: [value: Locale], saveKey: [value: string], removeKey: [], shortcuts: [] }>()
const languages = locales.map(value => ({ value, label: localeNames[value] }))
const opacity = defineModel<number>('opacity', { required: true })
const dark = defineModel<boolean>('dark', { required: true })
const focus = defineModel<boolean>('focus', { required: true })
const mirror = defineModel<boolean>('mirror', { required: true })
const depthMotion = defineModel<boolean>('depthMotion', { required: true })
const sceneBackdrop = defineModel<boolean>('sceneBackdrop', { required: true })
const curvedHud = defineModel<boolean>('curvedHud', { required: true })
const speechFeedback = defineModel<boolean>('speechFeedback', { required: true })
const shortcutsEnabled = defineModel<boolean>('shortcutsEnabled', { required: true })
const resetOpen = shallowRef(false)
const keyDraft = shallowRef('')
function saveKey() {
  if (keyDraft.value.trim())
    emit('saveKey', keyDraft.value)
  keyDraft.value = ''
}
function focusResetTrigger(event: MouseEvent) {
  // Safari does not focus a button on pointer click; the dialog needs its trigger focused.
  if (event.currentTarget instanceof HTMLElement)
    event.currentTarget.focus({ preventScroll: true })
}
function openShortcuts(event: MouseEvent) {
  // The dialog returns focus to whatever had it when it opened.
  focusResetTrigger(event)
  emit('shortcuts')
}
function selectLocale(value: string | undefined) {
  const next = resolveLocale(value)
  if (next)
    emit('locale', next)
}
function reset() {
  emit('reset')
  resetOpen.value = false
}
</script>

<template>
  <div class="feature-body">
    <div class="display-fields">
      <AgmSelect :model-value="locale" :label="t('settings.language')" :options="languages" @update:model-value="selectLocale" />
      <AgmSlider v-model="opacity" :label="t('settings.opacity')" :min="60" />
      <AgmSwitch v-model="dark" :label="t('settings.dark')" />
      <AgmSwitch v-model="focus" :label="t('settings.focus')" />
      <AgmSwitch v-model="mirror" :label="t('settings.mirror')" />
    </div>
    <fieldset class="visual-effects">
      <legend>{{ t('module.commands') }}</legend>
      <AgmSwitch v-model="speechFeedback" :label="t('settings.speechFeedback')" :disabled="!speechFeedbackSupported" />
      <p>{{ t(speechFeedbackSupported ? 'settings.speechFeedbackHint' : 'settings.speechFeedbackUnsupported') }}</p>
    </fieldset>
    <fieldset class="visual-effects">
      <legend>{{ t('settings.assistant') }}</legend>
      <p v-if="assistantNative" class="assistant-status" role="status">{{ t(assistantReady ? 'settings.assistantNativeOn' : 'settings.assistantNativeOff') }}</p>
      <template v-else-if="assistantReady">
        <p class="assistant-status" role="status">{{ t('settings.assistantKeySaved') }}</p>
        <AgmButton class="full-button" variant="outline" @click="$emit('removeKey')">{{ t('settings.assistantRemoveKey') }}</AgmButton>
      </template>
      <form v-else class="assistant-key" @submit.prevent="saveKey">
        <AgmInput v-model="keyDraft" type="password" :label="t('settings.assistantKey')" autocomplete="off" spellcheck="false" />
        <AgmButton type="submit" variant="outline" :disabled="!keyDraft.trim()">{{ t('settings.assistantSaveKey') }}</AgmButton>
      </form>
      <p>{{ t(assistantNative ? 'settings.assistantNativeHint' : 'settings.assistantHint') }}</p>
    </fieldset>
    <fieldset class="visual-effects">
      <legend>{{ t('settings.effects') }}</legend>
      <AgmSwitch v-model="sceneBackdrop" :label="t('settings.sceneBackdrop')" />
      <p>{{ t('settings.sceneBackdropHint') }}</p>
      <AgmSwitch v-model="depthMotion" :label="t('settings.depthMotion')" />
      <p>{{ t('settings.depthMotionHint') }}</p>
      <AgmSwitch v-model="curvedHud" :label="t('settings.curvedHud')" />
      <p>{{ t('settings.curvedHudHint') }}</p>
      <p v-if="reducedMotion" class="motion-note" role="status">{{ t('settings.reducedMotion') }}</p>
    </fieldset>
    <fieldset class="visual-effects">
      <legend>{{ t('settings.shortcuts') }}</legend>
      <AgmSwitch v-model="shortcutsEnabled" :label="t('shortcuts.enabled')" />
      <p>{{ t('settings.shortcutsHint') }}</p>
      <AgmButton class="full-button" variant="outline" @click="openShortcuts">{{ t('settings.shortcutsOpen') }}</AgmButton>
    </fieldset>
    <p class="settings-hint">{{ t('settings.hint') }}</p>
    <p class="settings-storage" role="status">{{ t(storageAvailable ? 'settings.storageSaved' : 'settings.storageUnavailable') }}</p>
    <AgmDialog v-model:open="resetOpen" :title="t('settings.reset')" :description="t('settings.resetDescription')" :close-label="t('settings.closeDialog')">
      <template #trigger><AgmButton class="full-button" variant="outline" @click="focusResetTrigger">{{ t('settings.reset') }}</AgmButton></template>
      <template #footer><AgmButton variant="ghost" @click="resetOpen = false">{{ t('settings.cancel') }}</AgmButton><AgmButton @click="reset">{{ t('settings.confirmReset') }}</AgmButton></template>
    </AgmDialog>
  </div>
</template>

<style scoped>
.display-fields { display: grid; gap: 25px; margin: 26px 0; }
.visual-effects { display: grid; gap: 12px; margin: 0 0 24px; padding: 18px 0 0; border: 0; border-top: 1px solid var(--agm-border); }
.visual-effects legend { padding: 0 12px 0 0; font-size: 12px; color: white; }
.visual-effects p { margin: -4px 0 6px; font-size: 11px; color: var(--agm-muted); line-height: 1.7; }
.visual-effects .motion-note { margin: 0; color: #c0e497; }
.visual-effects .assistant-status { margin: 0; font-size: 12px; color: white; }
.assistant-key { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: end; gap: 10px; }
.settings-hint, .settings-storage { font-size: 12px; color: var(--agm-muted); line-height: 1.8; }
.settings-storage { border-top: 1px solid var(--agm-border); padding-top: 20px; margin: 24px 0 20px; }
</style>
