<template>
  <li class="agm-select-dropdown__item" @click.stop="selectOptionClick">
    <slot>
      <span>{{ label }}</span>
    </slot>
  </li>
</template>

<script lang="ts">
import {
  toRefs,
  defineComponent,
  getCurrentInstance,
  onBeforeUnmount,
  reactive,
} from "vue";
import { useOption } from "./useOption";

export default defineComponent({
  name: "AgmOption",
  props: {
    label: {
      type: String,
      default: "",
    },
    value: {
      type: String,
      default: "",
    },
  },
  setup(props) {
    const { select } = useOption(props);

    function selectOptionClick() {
      if (props.disable) return;

      select.handleOptionSelect({
        label: props.label,
        value: props.value,
      });
    }

    return {
      select,
      selectOptionClick,
    };
  },
});
</script>

<style lang="scss">
.agm-select-dropdown__item {
  display: block;
  padding: 0.5rem 0.8rem;
  &:hover {
    background: #f6f6f6;
  }
}
</style>
