<template>
  <div ref="selectWrapper" class="agm-select" @click.stop="toggleMenu">
    <agm-popper ref="popper" placement="bottom" trigger="click">
      <template #trigger>
        <agm-input :placeholder="placeholder" />
      </template>
      <template #default>
        <agm-select-menu>
          <agm-option
            v-for="item in options"
            :label="item.label"
            :value="item.value"
          ></agm-option>
        </agm-select-menu>
      </template>
    </agm-popper>
  </div>
</template>

<script lang="ts">
import AgmPopper from "@augma/components/popper";
import AgmInput from "@augma/components/input/index.vue";
import AgmSelectMenu from "./src/SelectMenu.vue";
import AgmOption from "./src/Option.vue";
import {
  defineComponent,
  onMounted,
  ref,
  PropType,
  provide,
  reactive,
} from "vue";
import { selectKey } from "./src/useOption";

interface ISelectOption {
  label: string;
  value: any;
}

export default defineComponent({
  name: "AgmSelect",
  components: {
    AgmInput,
    AgmOption,
    AgmPopper,
    AgmSelectMenu,
  },
  props: {
    options: {
      type: Object as PropType<ISelectOption[]>,
    },
    placeholder: {
      type: String,
    },
  },
  setup(props, ctx) {
    provide(
      selectKey,
      reactive({
        props,
      })
    );
  },
});
</script>
