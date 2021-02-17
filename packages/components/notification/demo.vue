<template>
  <agm-button type="primary" @click="notify">弹出消息通知</agm-button>
</template>

<script lang="ts">
import "./index.ts";
import AgmButton from "../button/index.vue";
import { defineComponent } from "vue";
import pkg from "../../../package.json";
export default defineComponent({
  components: {
    AgmButton,
  },
  methods: {
    notify() {
      this.$notify({
        title: "GitHub",
        // icon: mdiGithub,
        color: "black",
        message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
        duration: 0,
      });
    },
  },
});
</script>
