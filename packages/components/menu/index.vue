<template>
  <div class="agm-menu">
    <div class="agm-menu--activator" @click="handleClick">
      <slot name="activator"></slot>
    </div>

    <transition name="slide-fade">
      <div v-if="modelValue" class="agm-menu-items">
        <slot></slot>
      </div>
    </transition>
  </div>
</template>

<script lang="ts">
import "./index.scss";
import { defineComponent } from "vue";
import { UPDATE_MODEL_EVENT } from "../dialog/dialog";
export default defineComponent({
  name: "AgmMenu",
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    handleClick() {
      this.$emit(UPDATE_MODEL_EVENT, !this.modelValue);
    },
  },
});
</script>

