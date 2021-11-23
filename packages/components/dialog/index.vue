<template>
  <teleport to="body">
    <transition name="agm-dialog-fade">
      <div
        v-show="visible"
        ref="dialogRef"
        :class="['agm-dialog']"
        role="dialog"
        @click.stop=""
      >
        <div class="agm-dialog--header">
          <div class="agm-dialog--title">
            <slot name="header"></slot>
          </div>
          <div class="agm-dialog--action">
            <button class="agm-dialog__fullscreenBtn" @click="toggle">
              <agm-icon icon="mdi:fullscreen" size="0.7rem" />
            </button>
            <button
              class="agm-dialog__closeBtn"
              aria-label="close"
              @click="handleClose"
            >
              <agm-icon icon="mdi:close" size="0.7rem" />
            </button>
          </div>
        </div>
        <slot class="agm-dialog--body"></slot>
      </div>
    </transition>
  </teleport>
</template>

<script lang="ts">
import './index.scss'

import { defineComponent, ref } from 'vue'
import { useFullscreen } from '@vueuse/core'
import AgmIcon from '../icon/index.vue'
import { UPDATE_MODEL_EVENT } from './dialog'

export default defineComponent({
  name: 'AgmDialog',
  components: {
    AgmIcon,
  },
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
  },
  emits: [UPDATE_MODEL_EVENT],
  setup(props, ctx) {
    const dialogRef = ref<HTMLElement | null>(null)
    const { toggle } = useFullscreen(dialogRef)
    return {
      // ...useDialog(props, ctx as SetupContext, dialogRef),
      dialogRef,
      toggle,
    }
  },
  data() {
    return {
      visible: false,
    }
  },
  watch: {
    modelValue(val) {
      if (val)
        this.open()
      else
        this.close()
    },
  },
  mounted() {
    if (this.modelValue) {
      this.visible = true
      this.open()
    }
  },
  methods: {
    open() {
      this.doOpen()
    },
    doOpen() {
      this.visible = true
    },
    handleClose() {
      this.close()
    },
    close() {
      // update v-model
      this.$emit(UPDATE_MODEL_EVENT, false)
      this.doClose()
    },
    doClose() {
      this.visible = false
    },
  },
})
</script>
