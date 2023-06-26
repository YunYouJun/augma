<script lang="ts" setup>
import { AgmInput, AgmPopper } from 'augma'
import { onClickOutside } from '@vueuse/core'
import {
  onMounted,
  provide,
  reactive,
  ref,
} from 'vue'
import { UPDATE_MODEL_EVENT } from '@augma/utils'
import AgmSelectMenu from './SelectMenu.vue'
import AgmOption from './Option.vue'

import type { ISelectOption } from './useOption'
import { selectKey } from './useOption'

const props = defineProps<{
  modelValue: ISelectOption
  options: ISelectOption[]
  placeholder: string
  callback: Function
}>()

const emit = defineEmits([UPDATE_MODEL_EVENT])

const selectWrapper = ref(null)
const popperRef = ref(null)
const minWidth = ref('0')

const currentOption = reactive<ISelectOption>(props.modelValue)

function calculateMinWidth() {
  return getComputedStyle(selectWrapper.value).width
}

onMounted(() => {
  minWidth.value = calculateMinWidth()
  window.onresize = () => {
    minWidth.value = calculateMinWidth()
  }
})

/**
 * handle child option
 */
function handleOptionSelect(val: ISelectOption) {
  currentOption.label = val.label
  currentOption.value = val.value
  emit(UPDATE_MODEL_EVENT, val)

  props.callback(val)
  popperRef.value.visibility = false
}

onClickOutside(selectWrapper, () => {
  popperRef.value.visibility = false
})

provide(
  selectKey,
  reactive({
    props,
    handleOptionSelect,
  }),
)
</script>

<template>
  <div ref="selectWrapper" class="agm-select" @click.stop="">
    <AgmPopper ref="popperRef" placement="bottom" trigger="click">
      <template #trigger>
        <AgmInput
          v-model="currentOption.label"
          readonly
          :placeholder="placeholder"
        />
      </template>
      <template #default>
        <AgmSelectMenu :min-width="minWidth">
          <AgmOption
            v-for="(item, i) in options"
            :key="i"
            :label="item.label"
            :value="item.value"
          />
        </AgmSelectMenu>
      </template>
    </AgmPopper>
  </div>
</template>
