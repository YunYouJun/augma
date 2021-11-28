<template>
  <table v-if="props" class="agm-table">
    <thead>
      <tr>
        <th>参数</th>
        <th>说明</th>
        <th>类型</th>
        <th>可选值</th>
        <th>默认值</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="(prop, i) in props" :key="i">
        <td font="bold">{{ prop.name }}</td>
        <td>{{ prop.description }}</td>
        <td><code>{{ prop.type }}</code></td>
        <td>
          <code>
            {{ formatValues(prop.acceptedValues) }}
          </code>
        </td>
        <td><code>{{ prop.default || "-" }}</code></td>
      </tr>
    </tbody>
  </table>
</template>

<script lang="ts" setup>
import { AgmTypeArray } from "@augma/shared";

export interface ComponentPropType {
  name: string;
  description: string;
  type: string;
  acceptedValues: string;
  default: string;
}

defineProps<{
  props: ComponentPropType[]
}>()


function formatValues(values) {
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
