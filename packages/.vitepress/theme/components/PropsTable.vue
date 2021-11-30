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
          <OptionalValue :type="prop.type" :accepted-values="prop.acceptedValues" />
        </td>
        <td><code>{{ prop.default || "-" }}</code></td>
      </tr>
    </tbody>
  </table>
</template>

<script lang="ts" setup>
import { agmColors } from "augma";

export type OptionalType = 'AgmColorType' | 'string' | 'boolean' | 'any' | ''

export interface ComponentPropType {
  name: string;
  description: string;
  type: OptionalType;
  acceptedValues: string;
  default: string;
}

defineProps<{
  props: ComponentPropType[]
}>()



</script>
