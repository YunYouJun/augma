<template>
  <teleport to="body">
    <transition name="agm-dialog-fade">
      <div
        v-show="visible"
        :class="['agm-dialog']"
        role="dialog"
        @click="$event.stopPropagation()"
        ref="agmDialog"
      >
        <slot></slot>
        <button
          class="agm-dialog__fullscreenBtn"
          @click="toggleFullscreen"
        ></button>
        <button
          class="agm-dialog__closeBtn"
          aria-label="close"
          @click="handleClose"
        ></button>
      </div>
    </transition>
  </teleport>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import { clearTimer } from "../../utils/util";
import { toggleFullscreen } from "../../utils/functions";

export default defineComponent({
  name: "AgmDialog",
  data() {
    return {
      visible: false,
    };
  },
  props: {
    modelValue: {
      type: Boolean,
      required: true,
    },
    /**
     * 打开延时
     */
    openDelay: {
      type: Number,
      default: 0,
    },
  },
  watch: {
    modelValue(val) {
      if (val) {
        this.closed = false;
        this.open();
      } else {
        this.close();
      }
    },
  },
  mounted() {
    if (this.modelValue) {
      this.visible = true;
      this.open();
    }
  },
  methods: {
    open() {
      this.doOpen();
    },
    doOpen() {
      this.visible = true;
    },
    handleClose() {
      this.close();
    },
    close() {
      // update v-model
      this.$emit("update:modelValue", false);
      this.doClose();
    },
    doClose() {
      this.closed = true;
      this.visible = false;
    },
    toggleFullscreen() {
      toggleFullscreen(this.$refs.agmDialog);
    },
  },
});
</script>
