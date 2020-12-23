<template>
  <agm-dialog v-model="browser">
    <iframe
      frameborder="0"
      src="https://docs.augma.elpsy.cn"
      width="100%"
      height="100%"
    ></iframe>
  </agm-dialog>
</template>

<script>
export default {
  computed: {
    browser: {
      get() {
        return this.$store.state.windows.browser;
      },
      set(value) {
        this.$store.commit("windows/setBrowser", value);
      },
    },
  },
};
</script>
