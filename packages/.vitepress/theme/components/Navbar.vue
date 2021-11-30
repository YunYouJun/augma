<script setup lang="ts">
import NavBarTitle from 'vitepress/dist/client/theme-default/components/NavBarTitle.vue'
import NavLinks from './NavLinks.vue'
import ToggleSideBarButton from 'vitepress/dist/client/theme-default/components/ToggleSideBarButton.vue'
import { useRepo } from 'vitepress/dist/client/theme-default/composables/repo'

defineEmits(['toggle'])

const repo = useRepo()
</script>

<template>
  <header class="nav-bar">
    <ToggleSideBarButton @toggle="$emit('toggle')" />

    <NavBarTitle />

    <div class="flex-grow" />

    <div class="nav">
      <NavLinks />
    </div>

    <div class="nav-icons flex items-center" m="l-2">
      <a v-if="repo" class="icon-button mx-2 text-black" :href="repo.link" target="_blank" aria-label="View GitHub Repo">
        <i-ri-github-line />
      </a>
      <dark-mode-switch class="mx-2" />
    </div>

    <slot name="search" />
  </header>
</template>

<style scoped>
.nav-bar {
  position: fixed;
  top: 0;
  right: 0;
  left: 0;
  z-index: var(--z-index-navbar);
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--c-divider);
  padding: 0.7rem 1.5rem 0.7rem 4rem;
  height: var(--header-height);
  background-color: var(--c-bg);
}

@media (min-width: 720px) {
  .nav-bar {
    padding: 0.7rem 1.5rem;
  }
}

.flex-grow {
  flex-grow: 1;
}

.nav {
  display: none;
}

@media (min-width: 720px) {
  .nav {
    display: block;
  }
}
</style>
