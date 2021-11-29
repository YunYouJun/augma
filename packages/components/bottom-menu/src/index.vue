<template>
  <div class="agm-bottom-menu">
    <div class="agm-down-arrow" />
    <div class="agm-bottom-menu--inner">
      <div class="agm-menu-container">
        <agm-button
          v-for="(item, i) in menuItems"
          :key="i"
          icon
          @click="item.do"
        >
          <agm-icon :name="item.icon" :color="item.color" />
        </agm-button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { AgmButton, AgmIcon } from 'augma'
import './index.scss'

export interface IMenuItem {
  color?: string
  icon?: string
  do?: () => void
}

withDefaults(defineProps<{menuItems: IMenuItem[]}>(), {
  menuItems: () => [],
})
</script>
