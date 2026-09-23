<script setup lang="ts">
import { AgmInput } from 'augma'
import { computed, shallowRef } from 'vue'
import { components } from '../../../../../scripts/catalog.mjs'

const query = shallowRef('')
const filtered = computed(() =>
  components.filter(item =>
    `${item.name} ${item.title} ${item.description}`
      .toLowerCase()
      .includes(query.value.trim().toLowerCase()),
  ),
)
</script>

<template>
  <div class="catalog">
    <AgmInput
      v-model="query"
      label="查找组件"
      placeholder="搜索名称或用途…"
      type="search"
    />
    <ul class="catalog-list">
      <li v-for="item in filtered" :key="item.slug">
        <a :href="`/components/${item.slug}`">
          <strong>{{ item.title }}</strong>
          <span>{{ item.description }}</span>
          <small>{{ item.group }}</small>
        </a>
      </li>
    </ul>
    <p v-if="!filtered.length" role="status">
      没有匹配的组件，试试其他关键词。
    </p>
  </div>
</template>
