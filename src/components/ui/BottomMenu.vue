<template>
  <div class="augma-bottom-menu">
    <div class="agm-bottom-menu">
      <div class="down-arrow"></div>
      <div class="agm-menu-container">
        <agm-button icon color="#8dd3d6" @click="flipScreen">
          <agm-icon :icon="icons.mdiFlipHorizontal"></agm-icon>
        </agm-button>
        <agm-button
          v-for="(item, i) in menuItems"
          :key="i"
          icon
          :color="item.color"
        >
          <agm-icon v-if="item.icon" :icon="item.icon" />
        </agm-button>
      </div>
    </div>
  </div>
</template>

<script>
import AgmButton from "../button/index.vue";
import AgmIcon from "../icon/index.vue";
import { mdiCloud, mdiEarth, mdiFlipHorizontal, mdiMap } from "@mdi/js";
export default {
  components: {
    AgmButton,
    AgmIcon,
  },
  data() {
    return {
      icons: {
        mdiFlipHorizontal,
      },
      menuItems: [
        {
          color: "#4dade0",
          icon: mdiCloud,
        },
        {
          color: "#dd9d5e",
          icon: mdiMap,
        },
        {
          color: "#4dade0",
          icon: mdiEarth,
        },
      ],
    };
  },
  methods: {
    flipScreen() {
      console.log(this.$store);
      this.$store.commit("app/toggleFlipScreen");
      console.log(this.$store.state.app.flipScreen);
    },
  },
};
</script>

<style lang="scss">
$bottom-nav-color: white;

.augma-bottom-menu {
  width: 100%;
  margin: 0 auto;
}

.agm-bottom-menu {
  display: inline-flex;
  height: 2rem;
  min-width: 20rem;
  padding: 1rem 3rem;
  border-top: 2px solid $bottom-nav-color;
}

.down-arrow {
  position: absolute;
  margin: 0 auto;
  top: 0;
  left: 0;
  right: 0;
  width: 0;
  height: 0;
  border: 10px solid $bottom-nav-color;
  border-color: $bottom-nav-color transparent transparent transparent;
}

.agm-menu-container {
  display: flex;
  margin: 0 auto;
  gap: 1.5rem;
}
</style>
