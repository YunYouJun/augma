<template>
  <VMenu v-if="type === 'AgmColorType'">
    <code class="text-purple-600 cursor-pointer">{{ type }}</code>

    <template #popper>
      <code class="mr-1 " text="sm" v-for="(value) in acceptedValuesByType(type)" :class="`text-${value}-500`">
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
  <code v-else class="mr-1" v-for="(value) in acceptedValuesByType(type)">
    <span>
      {{value}}
      <!-- {{ formatValues(acceptedValuesByType(type)) }} -->
    </span>
  </code>
</template>

<script lang="ts" setup>
import { agmColors } from "augma";
import { AgmTypeArray } from "@augma/shared";
import type { OptionalType } from './PropsTable.vue'

defineProps<{
  type: OptionalType,
  acceptedValues?: string[] | string
}>()

function acceptedValuesByType(type: OptionalType) {
  let acceptedValues: string[] = ['-'];
  switch (type) {
    case 'AgmColorType':
      acceptedValues = agmColors;
      break
    case 'boolean':
      acceptedValues = ['true', 'false'];
      break
    default:
      break
  }
  return acceptedValues
}
</script>
