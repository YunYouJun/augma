<template>
  <div>
    <agm-button type="primary" @click="openLoading">打开 Loading</agm-button>
  </div>
</template>

<script lang="ts">
import AgmLoading from "./index";
import AgmButton from "../button/index.vue";
import { defineComponent } from "vue";
export default defineComponent({
  components: {
    AgmButton,
  },
  methods: {
    openLoading() {
      console.log("open loading");
      this.$loading = AgmLoading.service();
      setTimeout(() => {
        this.$loading.close();
      }, 2000);
    },
  },
});
</script>
