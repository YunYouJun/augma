<template>
  <code>
    <span>
      {{ formatValues(acceptedValuesByType(type)) }}
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

function formatValues(values: string[] | string) {
  if (values === "AgmTypeArray") {
    values = AgmTypeArray;
  }
  if (Array.isArray(values)) {
    return values.join(" / ");
  } else {
    return values || "-";
  }
}
</script>
