<script lang="ts">
import './index.scss'

import {
  defineComponent,
  onActivated,
  onBeforeUnmount,
  onDeactivated,
  onMounted,
} from 'vue'
import throwError from '@augma/utils/error'
import defaultProps from './usePopper/default'

import usePopper from './usePopper'

const compName = 'AgmPopper'
export default defineComponent({
  name: compName,
  props: defaultProps,

  setup(props, ctx) {
    if (!ctx.slots.trigger)
      throwError(compName, 'Trigger must be provided')

    const popperStates = usePopper(props, ctx)

    const forceDestroy = () => popperStates.doDestroy(true)
    onMounted(popperStates.initializePopper)
    onBeforeUnmount(forceDestroy)
    onActivated(popperStates.initializePopper)
    onDeactivated(forceDestroy)

    return popperStates
  },
})
</script>

<template>
  <div class="agm-popper">
    <div ref="triggerRef" class="agm-popper--trigger" v-on="{ ...events }">
      <slot name="trigger" />
    </div>
    <div
      v-show="visibility"
      ref="popperRef"
      class="agm-popper--body"
      :style="popperStyle"
    >
      <slot name="default" />
    </div>
  </div>
</template>
