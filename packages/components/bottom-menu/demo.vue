<script lang="ts" setup>
import consola from 'consola'
import AgmBottomMenu from './src/index.vue'

const menuItems = [
  {
    color: 'black',
    icon: 'i-mdi-github',
    do: () => {
      consola.info('https://github.com/YunYouJun/augma')
    },
  },
  {
    color: 'var(--agm-color-success)',
    icon: 'i-mdi-check',
    do: () => {
      consola.success('success')
    },
  },
  {
    color: 'var(--agm-color-danger)',
    icon: 'i-mdi-error',
    do: () => {
      consola.error('error')
    },
  },
]
</script>

<template>
  <div class="demo-dark-bg">
    <AgmBottomMenu :menu-items="menuItems" />
  </div>
</template>

<style>
.demo-dark-bg {
  padding-top: 1rem;
  background: #333;
}
</style>
