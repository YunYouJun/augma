<template>
  <button
    :class="classes"
    :style="styles"
    :type="nativeType"
    @click="handleClick"
  >
    <slot></slot>
  </button>
</template>

<script lang="ts">
import { computed, defineComponent, PropType } from "vue";
import "./index.scss";
import { AgmColorType, AgmTypeArray } from "@augma/shared";

type IButtonNativeType = PropType<"button" | "submit" | "reset">;

export default defineComponent({
  name: "AgmButton",
  props: {
    color: String,
    icon: Boolean,
    type: {
      type: String as PropType<AgmColorType>,
      default: "default",
      validator: (type: AgmColorType) => {
        return AgmTypeArray.includes(type);
      },
    },
    outline: {
      type: Boolean,
      default: false,
    },
    nativeType: {
      type: String as IButtonNativeType,
      default: "button",
      validator: (val: string) => {
        return ["button", "submit", "reset"].includes(val);
      },
    },
    onClick: {
      type: Function,
    },
  },

  emits: ["click"],

  setup(props, ctx) {
    const handleClick = (evt: MouseEvent) => {
      ctx.emit("click", evt);
    };

    const classes = computed(() => {
      return [
        "agm-button",
        props.icon ? "agm-button--icon" : "",
        props.type ? `agm-button--${props.type}` : "",
        props.outline ? `is-outline` : "",
      ];
    });

    const styles = computed(() => {
      return {
        color: props.color,
      };
    });

    return {
      classes,
      styles,

      handleClick,
    };
  },
});
</script>
