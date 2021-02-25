<template>
  <div class="agm-indicator" :style="styles">
    <h2 class="agm-indicator__title">
      {{ title }}
    </h2>
    <div class="agm-indicator__info">
      {{ info }}
    </div>
    <div class="agm-indicator__cursor"></div>
  </div>
</template>

<script lang="ts">
import { getAgmColorByType } from "@augma/shared";
import { defineComponent } from "vue";
import "./index.scss";
export default defineComponent({
  name: "AgmIndicator",
  props: {
    title: {
      type: String,
      default: "Asuna",
    },
    info: {
      type: String,
      default: "318",
    },
    color: {
      type: String,
      default: "",
    },
  },
  computed: {
    styles() {
      return {
        color: getAgmColorByType(this.color),
      };
    },
  },
});
</script>
