<template>
  <agm-menu v-model="open">
    <template #activator>
      <agm-button icon>
        <agm-icon icon="mdi:dots-vertical" v-if="open" />
        <agm-icon icon="mdi:dots-horizontal" v-else />
      </agm-button>
    </template>
    <agm-button icon type="primary" outline>
      <agm-icon icon="mdi:fullscreen" />
    </agm-button>
    <agm-button icon type="success" outline>
      <agm-icon icon="mdi:check" />
    </agm-button>
  </agm-menu>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import AgmButton from "../button/index.vue";
import AgmIcon from "../icon/index.vue";
import AgmMenu from "./index.vue";

export default defineComponent({
  components: {
    AgmButton,
    AgmIcon,
    AgmMenu,
  },
  data() {
    return {
      open: false,
    };
  },
});
</script>
