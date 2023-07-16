<script lang="ts" setup>
import { agmColors } from 'augma'
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
    <code class="cursor-pointer text-purple-600">{{ type }}</code>

    <template #popper>
      <code v-for="(value) in acceptedValuesByType(type)" :key="value" class="mr-1" text="sm" :class="`text-${value}-500`">
        <span>
          {{ value }}
        </span>
      </code>
    </template>
  </VMenu>
  <template v-else-if="type === 'boolean'">
    <code class="mr-1 text-green-600">true</code>
    <code class="text-red-600">false</code>
  </template>
  <code v-for="(value) in acceptedValuesByType(type)" v-else :key="value" class="mr-1">
    <span>
      {{ value }}
      <!-- {{ formatValues(acceptedValuesByType(type)) }} -->
    </span>
  </code>
</template>
