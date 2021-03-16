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
        <td>{{ prop.name }}</td>
        <td>{{ prop.description }}</td>
        <td>{{ prop.type }}</td>
        <td>{{ formatValues(prop.acceptedValues) }}</td>
        <td>{{ prop.default || "-" }}</td>
      </tr>
    </tbody>
  </table>
</template>

<script lang="ts">
import { AgmTypeArray } from "@augma/shared";
import { PropType } from "vue-demi";

export interface ComponentPropType {
  name: string;
  description: string;
  type: string;
  acceptedValues: string;
  default: string;
}

export default {
  props: {
    props: {
      type: Object as PropType<ComponentPropType[]>,
      default: null,
    },
  },
  methods: {
    formatValues(values) {
      if (values === "AgmTypeArray") {
        values = AgmTypeArray;
      }
      if (Array.isArray(values)) {
        return values.join(" / ");
      } else {
        return values || "-";
      }
    },
  },
};
</script>
