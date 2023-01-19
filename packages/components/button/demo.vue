<script lang="ts" setup>
import { AgmButton, AgmIcon, agmColors } from 'augma'

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
  <div class="flex justify-between flex-wrap">
    <AgmButton class="m-2">
      Button
    </AgmButton>
    <AgmButton v-for="(color, i) in agmColors" :key="i" class="m-2" :color="color">
      {{ color.toUpperCase() }}
    </AgmButton>
  </div>

  <div class="flex justify-between flex-wrap">
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

  <div class="flex justify-between flex-wrap">
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
</template>
