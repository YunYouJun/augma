<template>
  <div ref="selectWrapper" class="agm-select" @click.stop="toggleMenu">
    <agm-popper ref="popperRef" placement="bottom" trigger="click">
      <template #trigger>
        <agm-input v-model="currentOption.label" :placeholder="placeholder" />
      </template>
      <template #default>
        <agm-select-menu :minWidth="minWidth">
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
  computed,
  nextTick,
} from "vue";
import { selectKey } from "./src/useOption";
import func from "vue-temp/vue-editor-bridge";
import { UPDATE_MODEL_EVENT } from "@augma/utils/constants";

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
    modelValue: {
      type: Object,
      default() {
        return {
          label: "",
          value: "",
        };
      },
    },
    options: {
      type: Object as PropType<ISelectOption[]>,
    },
    placeholder: {
      type: String,
    },
    callback: {
      type: Function,
    },
  },
  setup(props, ctx) {
    const selectWrapper = ref(null);
    const minWidth = ref("0");

    const currentOption = ref({ label: "", value: "" });

    function calculateMinWidth() {
      return getComputedStyle(selectWrapper.value).width;
    }

    onMounted(() => {
      minWidth.value = calculateMinWidth();
      window.onresize = () => {
        minWidth.value = calculateMinWidth();
      };
    });

    function handleOptionSelect(val) {
      currentOption.value = val;
      ctx.emit(UPDATE_MODEL_EVENT, val);

      props.callback(val);
    }

    provide(
      selectKey,
      reactive({
        props,
        handleOptionSelect,
      })
    );

    return { currentOption, selectWrapper, minWidth };
  },
});
</script>
