<template>
  <transition name="fade">
    <div v-if="loading" class="agm-loading"></div>
  </transition>
</template>

<script lang="ts">
import { defineComponent } from "vue";

export default defineComponent({
  name: "AgmLoading",
  props: {
    loading: {
      type: Boolean,
      default: true,
    },
  },
});
</script>
