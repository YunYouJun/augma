<template>
  <transition name="fade">
    <div v-if="loading" class="agm-loading"></div>
  </transition>
</template>

<script>
export default {
  name: "AgmLoading",
  props: {
    loading: {
      type: Boolean,
      default: true,
    },
  },
};
</script>
