<template>
  <div>
    <table class="agm-table">
      <thead>
        <tr>
          <th>类型</th>
          <th>简介</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="category in categories">
          <td>{{ capitalize(category.name) }} {{ category.title }}</td>
          <td>{{ category.description }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import categoriesData from "../../../../../meta/categories.json";
import { capitalize } from "vue";

const props = withDefaults(defineProps<{type?: string}>(), {
  type: 'components'
})

const categories = categoriesData[props.type]
</script>
