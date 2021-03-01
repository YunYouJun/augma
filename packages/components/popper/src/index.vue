<template>
  <div class="agm-popper">
    <div class="agm-popper--trigger" ref="triggerRef" v-on="{ ...events }">
      <slot name="trigger"></slot>
    </div>
    <div v-show="visibility" class="agm-popper--body" ref="popperRef">
      <slot name="default"></slot>
    </div>
  </div>
</template>

<script lang="ts">
import "./index.scss";

import {
  defineComponent,
  onBeforeMount,
  onMounted,
  onActivated,
  onDeactivated,
} from "vue";
import defaultProps from "./usePopper/default";

import throwError from "@augma/utils/error";
import usePopper from "./usePopper";

const compName = "AgmPopper";
export default defineComponent({
  name: compName,
  props: defaultProps,

  setup(props, ctx) {
    if (!ctx.slots.trigger) {
      throwError(compName, "Trigger must be provided");
    }

    const popperStates = usePopper(props, ctx);

    const forceDestroy = () => popperStates.doDestroy(true);
    onMounted(popperStates.initializePopper);
    onBeforeMount(forceDestroy);
    onActivated(popperStates.initializePopper);
    onDeactivated(forceDestroy);

    return popperStates;
  },
});
</script>
