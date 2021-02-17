<template>
  <button :class="classes">
    <slot></slot>
  </button>
</template>

<script lang="ts">
import { defineComponent, PropType } from "vue";
import "./index.scss";
import { colorTypes, AgmColorType } from "@augma/shared";

type IButtonType = PropType<
  "primary" | "success" | "warning" | "danger" | "info" | "default"
>;

export default defineComponent({
  name: "AgmButton",
  props: {
    color: String,
    icon: Boolean,
    type: {
      type: String as IButtonType,
      default: "default",
      validator: (val: AgmColorType) => {
        return colorTypes.includes(val);
      },
    },
    outline: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    classes(): any {
      return [
        "agm-button",
        this.icon ? "agm-button--icon" : "",
        this.type ? `agm-button--${this.type}` : "",
        this.outline ? `is-outline` : "",
      ];
    },
  },
});
</script>
