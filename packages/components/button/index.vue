<template>
  <button :class="classes" @click="handleClick">
    <slot></slot>
  </button>
</template>

<script lang="ts">
import { computed, defineComponent, PropType } from "vue";
import "./index.scss";
import { AgmColorType, TypeArray } from "@augma/shared";

export default defineComponent({
  name: "AgmButton",
  props: {
    color: String,
    icon: Boolean,
    type: {
      type: String as PropType<AgmColorType>,
      default: "default",
      validator: (type: AgmColorType) => {
        return TypeArray.includes(type);
      },
    },
    outline: {
      type: Boolean,
      default: false,
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

    return {
      classes,

      handleClick,
    };
  },
});
</script>
