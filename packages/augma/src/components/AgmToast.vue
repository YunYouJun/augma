<script setup lang="ts">
import {
  injectToastProviderContext,
  ToastClose,
  ToastDescription,
  ToastPortal,
  ToastProvider,
  ToastRoot,
  ToastTitle,
  ToastViewport,
} from 'reka-ui'
import { defineComponent, h } from 'vue'

const props = withDefaults(
  defineProps<{
    title: string
    description?: string
    duration?: number
    tone?: 'success' | 'warning' | 'danger' | 'neutral'
    closeLabel?: string
    regionLabel?: string
  }>(),
  { duration: 5000, tone: 'success', closeLabel: '关闭通知', regionLabel: '通知（F8）' },
)
const open = defineModel<boolean>('open', { default: false })
const hasProvider = injectToastProviderContext(null) !== null

const ToastHost = defineComponent({
  name: 'AgmToastHost',
  setup(_, { slots }) {
    return () => {
      if (hasProvider)
        return slots.default?.()
      return h(ToastProvider, { duration: props.duration }, () =>
        h(ToastPortal, null, () => [
          slots.default?.(),
          h(ToastViewport, { class: 'agm-toast-viewport', label: props.regionLabel }),
        ]))
    }
  },
})
</script>

<template>
  <ToastHost>
    <ToastRoot
      v-model:open="open"
      :duration="duration"
      class="agm-toast"
      :data-tone="tone"
      :data-countdown="Number.isFinite(duration) || undefined"
      :style="Number.isFinite(duration) ? { '--agm-toast-duration': `${duration}ms` } : undefined"
    >
      <ToastTitle class="agm-toast-title">{{ title }}</ToastTitle>
      <ToastDescription v-if="description" class="agm-toast-description">
        {{ description }}
      </ToastDescription>
      <ToastClose
        class="agm-icon-button agm-dialog-close"
        :aria-label="closeLabel"
      >
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path d="m6 6 12 12M6 18 18 6" />
        </svg>
      </ToastClose>
    </ToastRoot>
  </ToastHost>
</template>
