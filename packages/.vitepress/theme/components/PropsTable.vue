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
      <tr v-for="prop in props">
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
import { TypeArray } from "@augma/shared";
export interface PropType {
  name: string;
  description: string;
  type: string;
  acceptedValues: string;
  default: string;
}
export default {
  props: {
    props: {
      type: Object,
      default: null,
    },
  },
  methods: {
    formatValues(values) {
      if (values === "TypeArray") {
        values = TypeArray;
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

<style lang="scss">
.agm-table {
  display: table;
  width: 100%;
}
</style>
