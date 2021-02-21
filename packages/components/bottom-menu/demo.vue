<template>
  <div class="demo-dark-bg">
    <agm-bottom-menu :menu-items="menuItems" />
  </div>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import AgmBottomMenu from "./index.vue";
export default defineComponent({
  components: {
    AgmBottomMenu,
  },
  data() {
    return {
      menuItems: [
        {
          color: "black",
          icon: "mdi:github",
          do: () => {
            console.log("github");
          },
        },
        {
          color: "var(--agm-success)",
          icon: "mdi:check",
          do: () => {
            console.log("yes");
          },
        },
        {
          color: "var(--agm-danger)",
          icon: "mdi:error",
          do: () => {
            console.log("no");
          },
        },
      ],
    };
  },
});
</script>

<style>
.demo-dark-bg {
  padding-top: 1rem;
  background: #333;
}
</style>
