<template>
  <div class="demo-dark-bg">
    <agm-bottom-menu :menu-items="menuItems" />
  </div>
</template>

<script lang="ts" setup>
import AgmBottomMenu from './index.vue'
const menuItems = [
  {
    color: 'black',
    icon: 'mdi:github',
    do: () => {
    },
  },
  {
    color: 'var(--agm-color-success)',
    icon: 'mdi:check',
    do: () => {
    },
  },
  {
    color: 'var(--agm-color-danger)',
    icon: 'mdi:error',
    do: () => {
    },
  },
]
</script>

<style>
.demo-dark-bg {
  padding-top: 1rem;
  background: #333;
}
</style>
