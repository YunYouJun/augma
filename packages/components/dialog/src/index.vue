<script lang="ts" setup>
import './index.scss'

import { onMounted, ref, watch } from 'vue'
import { useFullscreen } from '@vueuse/core'
import { AgmIcon } from 'augma'
import { UPDATE_MODEL_EVENT } from '../dialog'
const props = withDefaults(defineProps<{
  modelValue: boolean
}>(), {
  modelValue: false,
})
const emit = defineEmits([UPDATE_MODEL_EVENT])
const visible = ref(false)
const dialogRef = ref<HTMLElement>()
const { toggle } = useFullscreen(dialogRef)

watch(() => props.modelValue, (val) => {
  if (val)
    open()
  else
    close()
})

onMounted(() => {
  if (props.modelValue) {
    visible.value = true
    open()
  }
})

function open() {
  doOpen()
}
function doOpen() {
  visible.value = true
}
function handleClose() {
  close()
}
function close() {
  // update v-model
  emit(UPDATE_MODEL_EVENT, false)
  doClose()
}
function doClose() {
  visible.value = false
}
</script>

<template>
  <teleport to="body">
    <transition name="agm-dialog-fade">
      <div
        v-show="visible"
        ref="dialogRef"
        class="agm-dialog"
        role="dialog"
        @click.stop=""
      >
        <div class="agm-dialog--header">
          <div class="agm-dialog--title">
            <slot name="header" />
          </div>
          <div class="agm-dialog--action">
            <button class="agm-dialog__fullscreenBtn" @click="toggle">
              <AgmIcon icon="mdi:fullscreen" size="0.7rem" />
            </button>
            <button
              class="agm-dialog__closeBtn"
              aria-label="close"
              @click="handleClose"
            >
              <AgmIcon icon="mdi:close" size="0.7rem" />
            </button>
          </div>
        </div>
        <slot class="agm-dialog--body" />
      </div>
    </transition>
  </teleport>
</template>
