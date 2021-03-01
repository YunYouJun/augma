<template>
  <li class="agm-select-dropdown__item" @click.stop="selectOptionCLick">
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
import { SelectOptionProxy } from "./token";

export default defineComponent({
  name: "AgmOption",
  props: {
    label: {
      type: String,
      default: "",
    },
  },
  setup(props) {
    const { select } = useOption(props);

    console.log(select);
    return {
      select,
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
