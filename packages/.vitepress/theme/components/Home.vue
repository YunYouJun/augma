<template>
  <main class="home" aria-labelledby="main-title">
    <HomeHero />
    <slot name="hero" />
    <HomeFeatures />
    <slot name="features" />
    <HomeFooter />
    <slot name="footer" />
  </main>
</template>

<script setup lang="ts">
import HomeHero from './HomeHero.vue'
import HomeFeatures from 'vitepress/dist/client/theme-default/components/HomeFeatures.vue'
import HomeFooter from 'vitepress/dist/client/theme-default/components/HomeFooter.vue'
</script>

<style scoped>
.home {
  padding-top: var(--header-height);
}
</style>
