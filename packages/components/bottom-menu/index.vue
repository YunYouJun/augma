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
          <agm-icon v-if="item.icon" :icon="item.icon" />
        </agm-button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "AgmBottomMenu",
  props: {
    menuItems: {
      type: Array,
      default() {
        return [];
      },
    },
  },
};
</script>
