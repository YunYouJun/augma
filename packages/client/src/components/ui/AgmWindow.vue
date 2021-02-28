<template>
  <agm-weather v-if="$store.state.app.weather" />
  <agm-dialog v-if="browser" v-model="browser">
    <iframe
      frameborder="0"
      src="https://docs.augma.elpsy.cn"
      width="100%"
      height="100%"
    ></iframe>
  </agm-dialog>
  <agm-map :enable="$store.state.app.subwayMap" />
</template>

<script>
import AgmWeather from "../app/AgmWeather.vue";
import AgmMap from "../app/AgmMap.vue";
export default {
  components: { AgmMap, AgmWeather },
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
