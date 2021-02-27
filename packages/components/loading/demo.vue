<template>
  <div>
    <agm-button type="primary" @click="openLoading">打开 Loading</agm-button>
  </div>
</template>

<script lang="ts">
import AgmLoading from "./index";
import { defineComponent } from "vue";
export default defineComponent({
  methods: {
    openLoading() {
      this.$loading = AgmLoading.service();
      setTimeout(() => {
        this.$loading.close();
      }, 2000);
    },
  },
});
</script>
