<template>
  <div class="agm-bottom-menu">
    <div class="agm-down-arrow"></div>
    <div class="agm-bottom-menu--inner">
      <div class="agm-menu-container">
        <agm-button
          v-for="(item, i) in menuItems"
          :key="i"
          icon
          :color="item.color"
          @click="item.do"
        >
          <!-- icon -->
        </agm-button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import AgmButton from "../button/index.vue";
import { defineComponent, PropType } from "vue";

interface IMenuItem {
  color: string;
  icon: string;
  do: () => void;
}

export default defineComponent({
  name: "AgmBottomMenu",
  components: {
    AgmButton,
  },
  props: {
    menuItems: {
      type: Array as PropType<IMenuItem[]>,
      default() {
        return [];
      },
    },
  },
});
</script>
