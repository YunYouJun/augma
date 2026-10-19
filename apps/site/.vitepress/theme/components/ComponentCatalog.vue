<script setup lang="ts">
import { AgmButton, AgmInput } from 'augma'
import { computed, shallowRef } from 'vue'
import { groupNames, localizeComponents } from '../../../../../scripts/catalog-i18n.mjs'
import { useI18n } from '../i18n'
import CatalogPreview from './CatalogPreview.vue'

const { locale, t, link } = useI18n()
const components = computed(() => localizeComponents(locale.value))
// Filters keep the catalog's Chinese group key; only the label is translated.
const all = ''
const query = shallowRef('')
const group = shallowRef(all)
const groups = computed(() => [all, ...new Set(components.value.map(item => item.group))])
const groupName = (key: string) => key === all ? t('catalog.all') : groupNames[key as keyof typeof groupNames][locale.value]
const filtered = computed(() =>
  components.value.filter(item =>
    (group.value === all || item.group === group.value)
    && `${item.name} ${item.title} ${item.description} ${groupName(item.group)}`
      .toLowerCase()
      .includes(query.value.trim().toLowerCase()),
  ),
)
function reset() {
  query.value = ''
  group.value = all
}
</script>

<template>
  <div class="catalog">
    <AgmInput
      v-model="query"
      :label="t('catalog.search')"
      :placeholder="t('catalog.placeholder')"
      type="search"
    />
    <div class="catalog-filters" role="group" :aria-label="t('catalog.groups')">
      <button v-for="category in groups" :key="category" type="button" :aria-pressed="group === category" @click="group = category">
        {{ groupName(category) }}
      </button>
    </div>
    <p class="catalog-count" role="status">{{ t('catalog.count', { shown: filtered.length, total: components.length }) }}</p>
    <ul class="catalog-list">
      <li v-for="item in filtered" :key="item.slug" class="hud-brackets">
        <CatalogPreview :name="item.slug" />
        <a :href="link(`/components/${item.slug}`)">
          <strong>{{ item.title }}</strong>
          <span>{{ item.description }}</span>
          <small>{{ groupName(item.group) }}</small>
        </a>
      </li>
    </ul>
    <div v-if="!filtered.length" class="catalog-empty">
      <p>{{ t('catalog.empty') }}</p>
      <AgmButton variant="outline" @click="reset">{{ t('catalog.clear') }}</AgmButton>
    </div>
  </div>
</template>
