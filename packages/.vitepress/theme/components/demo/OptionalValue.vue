<script lang="ts" setup>
import { agmColors } from 'augma'
import { AgmTypeArray } from '@augma/shared'
import type { OptionalType } from './PropsTable.vue'

defineProps<{
  type: OptionalType
  acceptedValues?: string[] | string
}>()

function acceptedValuesByType(type: OptionalType) {
  let acceptedValues: string[] = ['-']
  switch (type) {
    case 'AgmColorType':
      acceptedValues = agmColors
      break
    case 'boolean':
      acceptedValues = ['true', 'false']
      break
    default:
      break
  }
  return acceptedValues
}
</script>

<template>
  <VMenu v-if="type === 'AgmColorType'">
    <code class="text-purple-600 cursor-pointer">{{ type }}</code>

    <template #popper>
      <code v-for="(value) in acceptedValuesByType(type)" class="mr-1 " text="sm" :class="`text-${value}-500`">
        <span>
          {{ value }}
        </span>
      </code>
    </template>
  </VMenu>
  <template v-else-if="type === 'boolean'">
    <code class="text-green-600 mr-1">true</code>
    <code class="text-red-600">false</code>
  </template>
  <code v-for="(value) in acceptedValuesByType(type)" v-else class="mr-1">
    <span>
      {{ value }}
      <!-- {{ formatValues(acceptedValuesByType(type)) }} -->
    </span>
  </code>
</template>
