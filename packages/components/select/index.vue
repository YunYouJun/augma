<template>
  <div ref="selectWrapper" class="agm-select" @click.stop="">
    <agm-popper ref="popperRef" placement="bottom" trigger="click">
      <template #trigger>
        <agm-input
          readonly
          v-model="currentOption.label"
          :placeholder="placeholder"
        />
      </template>
      <template #default>
        <agm-select-menu :minWidth="minWidth">
          <agm-option
            v-for="(item, i) in options"
            :key="i"
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

import { onClickOutside } from "@vueuse/core";

import {
  defineComponent,
  onMounted,
  ref,
  PropType,
  provide,
  reactive,
  computed,
  nextTick,
} from "vue";
import { selectKey, ISelectOption } from "./src/useOption";
import { UPDATE_MODEL_EVENT } from "@augma/utils/constants";

export default defineComponent({
  name: "AgmSelect",
  components: {
    AgmInput,
    AgmOption,
    AgmPopper,
    AgmSelectMenu,
  },
  props: {
    modelValue: Object as PropType<ISelectOption>,
    options: Object as PropType<ISelectOption[]>,
    placeholder: {
      type: String,
      default: "",
    },
    callback: Function,
  },
  setup(props, ctx) {
    const selectWrapper = ref(null);
    const popperRef = ref(null);
    const minWidth = ref("0");

    const currentOption = reactive<ISelectOption>({ label: "", value: "" });

    function calculateMinWidth() {
      return getComputedStyle(selectWrapper.value).width;
    }

    onMounted(() => {
      minWidth.value = calculateMinWidth();
      window.onresize = () => {
        minWidth.value = calculateMinWidth();
      };
    });

    const callback = props.callback;

    /**
     * handle child option
     */
    function handleOptionSelect(val: ISelectOption) {
      currentOption.value = val;
      ctx.emit(UPDATE_MODEL_EVENT, val);

      callback(val);
    }

    onClickOutside(selectWrapper, () => {
      popperRef.value.visibility = false;
    });

    provide(
      selectKey,
      reactive({
        props,
        handleOptionSelect,
      })
    );

    return {
      currentOption,
      selectWrapper,
      popperRef,
      minWidth,
    };
  },
});
</script>
