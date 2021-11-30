<template>
  <div class="button-demo">
    <agm-button class="m-2">
      Button
    </agm-button>
    <agm-button v-for="(color, i) in agmColors" :key="i" class="m-2" :color="color">
      {{ color.toUpperCase() }}
    </agm-button>
  </div>

  <div class="button-demo">
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

  <div class="button-demo">
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
</template>

<script lang="ts" setup>
import { AgmIcon, AgmButton, agmColors } from 'augma'

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

<style lang="scss">
.button-demo {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
}
</style>
