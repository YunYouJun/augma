<template>
  <div class="agm-system-bar">
    <agm-clock />
    <agm-hr />
  </div>
</template>

<script>
import AgmClock from "../clock/index.vue";
import AgmHr from "../html/AgmHr.vue";
export default {
  components: {
    AgmClock,
    AgmHr,
  },
};
</script>

<style lang="scss">
.agm-system-bar {
  margin: 2rem;
}
</style>
