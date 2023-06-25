<script lang="ts" setup>
import { capitalize } from 'vue'
import { categories as _categories } from '@augma/metadata'

const props = withDefaults(defineProps<{ type?: string }>(), {
  type: 'components',
})

const categories = _categories[props.type]
</script>

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
        <tr v-for="category in categories" :key="category.name">
          <td>{{ capitalize(category.name) }} {{ category.title }}</td>
          <td>{{ category.description }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
