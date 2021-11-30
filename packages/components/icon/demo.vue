<template>
  <div class="flex justify-between flex-wrap">
    <agm-button
      v-for="(item,i) in iconItems"
      :key="i"
      class="m-2"
      icon
      :color="item.color"
    >
      <agm-icon :name="item.icon" />
    </agm-button>
  </div>

  <div class="flex justify-between flex-wrap">
    <agm-button
      v-for="(item,i) in iconItems"
      :key="i"
      class="m-2"
      icon
      :color="item.color"
      plain
    >
      <agm-icon :name="item.icon" />
    </agm-button>
  </div>
  <div class="logo-demo text-center mt-5">
    <agm-icon
      name="i-mdi-do-not-disturb-off"
      color="var(--agm-color-danger)"
      size="10rem"
    />
  </div>
</template>

<script lang="ts" setup>
import { AgmButton, AgmIcon } from 'augma'
const iconItems = [
  {
    color: '',
    icon: 'i-mdi-github',
  },
  {
    color: 'blue',
    icon: 'i-mdi-vector-square',
  },
  {
    color: 'green',
    icon: 'i-mdi-check',
  },
  {
    color: 'yellow',
    icon: 'i-mdi-warning',
  },
  {
    color: 'red',
    icon: 'i-mdi-error',
  },
  {
    color: 'cyan',
    icon: 'i-mdi-information-variant',
  },
]
</script>
