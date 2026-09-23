<script setup lang="ts">
import { onUnmounted, shallowRef } from 'vue'
import UiIcon from './UiIcon.vue'

const props = defineProps<{ text: string }>()
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
      :aria-label="copied ? '已复制' : '复制命令'"
      @click="copy"
    >
      <UiIcon :name="copied ? 'check' : 'copy'" />
    </button>
    <span class="agm-sr-only" aria-live="polite">
      {{ copied ? '已复制到剪贴板' : error ? '复制失败，请选中文字复制' : '' }}
    </span>
  </div>
</template>
