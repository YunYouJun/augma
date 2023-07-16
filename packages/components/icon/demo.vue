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

<template>
  <div class="flex flex-wrap justify-between">
    <AgmButton
      v-for="(item, i) in iconItems"
      :key="i"
      class="m-2"
      icon
      :color="item.color"
    >
      <AgmIcon :name="item.icon" />
    </AgmButton>
  </div>

  <div class="flex flex-wrap justify-between">
    <AgmButton
      v-for="(item, i) in iconItems"
      :key="i"
      class="m-2"
      icon
      :color="item.color"
      plain
    >
      <AgmIcon :name="item.icon" />
    </AgmButton>
  </div>
  <div class="logo-demo mt-5 text-center">
    <AgmIcon
      name="i-mdi-do-not-disturb-off"
      color="var(--agm-color-danger)"
      size="10rem"
    />
  </div>
</template>
