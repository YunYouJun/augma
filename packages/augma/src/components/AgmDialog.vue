<script setup lang="ts">
import {
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogRoot,
  DialogTitle,
  DialogTrigger,
} from 'reka-ui'

defineProps<{ title: string, description: string }>()
const open = defineModel<boolean>('open', { default: false })
</script>

<template>
  <DialogRoot v-model:open="open">
    <DialogTrigger v-if="$slots.trigger" as-child>
      <slot name="trigger" />
    </DialogTrigger>
    <DialogPortal>
      <DialogOverlay class="agm-dialog-overlay" />
      <DialogContent class="agm-dialog">
        <DialogTitle class="agm-dialog-title">{{ title }}</DialogTitle>
        <DialogDescription class="agm-dialog-description">
          {{ description }}
        </DialogDescription>
        <slot />
        <DialogClose
          class="agm-icon-button agm-dialog-close"
          aria-label="关闭对话框"
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
        </DialogClose>
        <footer v-if="$slots.footer" class="agm-dialog-footer">
          <slot name="footer" />
        </footer>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
