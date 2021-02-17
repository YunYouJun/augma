<template>
  <agm-bottom-menu :menu-items="menuItems" />
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
          icon: "",
          do: () => {
            console.log("yes");
          },
        },
      ],
    };
  },
});
</script>
