<template>
  <div class="agm-bottom-menu">
    <div class="agm-down-arrow"></div>
    <div class="agm-bottom-menu--inner">
      <div class="agm-menu-container">
        <agm-button
          v-for="(item, i) in menuItems"
          :key="i"
          icon
          @click="item.do"
        >
          <agm-icon :icon="item.icon" :color="item.color"></agm-icon>
        </agm-button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import './index.scss'
import { defineComponent, PropType } from 'vue'
import AgmButton from '../button/index.vue'
import AgmIcon from '../icon/index.vue'

interface IMenuItem {
  color: string
  icon: string
  do: () => void
}

export default defineComponent({
  name: 'AgmBottomMenu',
  components: {
    AgmButton,
    AgmIcon,
  },
  props: {
    menuItems: {
      type: Array as PropType<IMenuItem[]>,
      default() {
        return []
      },
    },
  },
})
</script>
