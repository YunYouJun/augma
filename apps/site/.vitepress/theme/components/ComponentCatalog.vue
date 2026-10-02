<script setup lang="ts">
import { AgmButton, AgmInput } from 'augma'
import { computed, shallowRef } from 'vue'
import { components } from '../../../../../scripts/catalog.mjs'
import CatalogPreview from './CatalogPreview.vue'

const query = shallowRef('')
const group = shallowRef('全部')
const groups = ['全部', ...new Set(components.map(item => item.group))]
const filtered = computed(() =>
  components.filter(item =>
    (group.value === '全部' || item.group === group.value)
    && `${item.name} ${item.title} ${item.description} ${item.group}`
      .toLowerCase()
      .includes(query.value.trim().toLowerCase()),
  ),
)
function reset() {
  query.value = ''
  group.value = '全部'
}
</script>

<template>
  <div class="catalog">
    <AgmInput
      v-model="query"
      label="查找组件"
      placeholder="搜索名称或用途…"
      type="search"
    />
    <div class="catalog-filters" role="group" aria-label="组件分类">
      <button v-for="category in groups" :key="category" type="button" :aria-pressed="group === category" @click="group = category">
        {{ category }}
      </button>
    </div>
    <p class="catalog-count" role="status">显示 {{ filtered.length }} / {{ components.length }} 个组件</p>
    <ul class="catalog-list">
      <li v-for="item in filtered" :key="item.slug">
        <CatalogPreview :name="item.slug" />
        <a :href="`/components/${item.slug}`">
          <strong>{{ item.title }}</strong>
          <span>{{ item.description }}</span>
          <small>{{ item.group }}</small>
        </a>
      </li>
    </ul>
    <div v-if="!filtered.length" class="catalog-empty">
      <p>没有匹配的组件，试试其他关键词或分类。</p>
      <AgmButton variant="outline" @click="reset">清除筛选</AgmButton>
    </div>
  </div>
</template>
