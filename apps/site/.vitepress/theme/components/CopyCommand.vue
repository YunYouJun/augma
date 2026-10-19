<script setup lang="ts">
import { onUnmounted, shallowRef } from 'vue'
import { useI18n } from '../i18n'
import UiIcon from './UiIcon.vue'

const props = defineProps<{ text: string }>()
const { t } = useI18n()
const copied = shallowRef(false)
const error = shallowRef(false)
let timer: ReturnType<typeof setTimeout> | undefined
async function copy() {
  try {
    await navigator.clipboard.writeText(props.text)
    copied.value = true
    error.value = false
    clearTimeout(timer)
    timer = setTimeout(() => {
      copied.value = false
    }, 2000)
  }
  catch {
    error.value = true
  }
}
onUnmounted(() => clearTimeout(timer))
</script>

<template>
  <div class="copy-command">
    <code>{{ text }}</code>
    <button
      type="button"
      :aria-label="copied ? t('copy.copied') : t('copy.command')"
      @click="copy"
    >
      <UiIcon :name="copied ? 'check' : 'copy'" />
    </button>
    <span class="agm-sr-only" aria-live="polite">
      {{ copied ? t('copy.done') : error ? t('copy.failed') : '' }}
    </span>
  </div>
</template>
