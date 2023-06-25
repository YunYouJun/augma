<script lang="ts" setup>
import type { ISelectOption } from './src/useOption'
import AgmSelect from './src/index.vue'

const options: ISelectOption[] = [
  {
    label: 'Label A',
    value: 'A',
  },
  {
    label: 'Label B',
    value: 'B',
  },
  {
    label: 'Label C',
    value: 'C',
  },
]

const currentOption = reactive<ISelectOption>({
  label: '',
  value: '',
})

function callback(val: any) {
  // eslint-disable-next-line no-console
  console.log(val, currentOption)
}
</script>

<template>
  <AgmSelect
    v-model="currentOption"
    :options="options"
    placeholder="Placeholder"
    :callback="callback"
  />
</template>
