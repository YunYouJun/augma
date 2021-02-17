<template>
  <agm-menu v-model="open">
    <template #activator>
      <agm-button icon>
        <i-carbon-overflow-menu-vertical v-if="open" />
        <i-carbon-overflow-menu-horizontal v-else />
      </agm-button>
    </template>
    <agm-button icon type="primary" outline>
      <i-carbon-area />
    </agm-button>
    <agm-button icon type="success" outline>
      <i-carbon-battery-full />
    </agm-button>
  </agm-menu>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import AgmButton from "../button/index.vue";
import AgmMenu from "./index.vue";

export default defineComponent({
  components: {
    AgmButton,
    AgmMenu,
  },
  data() {
    return {
      open: false,
    };
  },
});
</script>
