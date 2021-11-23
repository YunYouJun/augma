<template>
  <agm-select
    v-model="currentOption"
    :options="options"
    placeholder="Placeholder"
    :callback="callback"
  ></agm-select>
</template>

<script lang="ts" setup>
import AgmSelect from './index.vue'
const options = [
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
const currentOption = ref({})

function callback(val: any) {
  // eslint-disable-next-line no-console
  console.log(val, this.currentOption)
}
</script>
