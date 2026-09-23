<script setup lang="ts">
import {
  ToastClose,
  ToastDescription,
  ToastPortal,
  ToastProvider,
  ToastRoot,
  ToastTitle,
  ToastViewport,
} from 'reka-ui'

withDefaults(
  defineProps<{ title: string, description?: string, duration?: number }>(),
  { duration: 5000 },
)
const open = defineModel<boolean>('open', { default: false })
</script>

<template>
  <ToastProvider :duration="duration">
    <ToastPortal>
      <ToastRoot v-model:open="open" class="agm-toast">
        <ToastTitle class="agm-toast-title">{{ title }}</ToastTitle>
        <ToastDescription v-if="description" class="agm-toast-description">
          {{ description }}
        </ToastDescription>
        <ToastClose
          class="agm-icon-button agm-dialog-close"
          aria-label="关闭通知"
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
      <ToastViewport class="agm-toast-viewport" label="通知（F8）" />
    </ToastPortal>
  </ToastProvider>
</template>
