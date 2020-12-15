<template>
  <div class="agm-system-bar">
    <agm-button icon class="agm-top-left-btn">
      <agm-icon :icon="icons.mdiMicrophone"></agm-icon>
    </agm-button>
    <agm-button icon class="agm-top-right-btn">
      <agm-icon :icon="icons.mdiDotsHorizontal"></agm-icon>
    </agm-button>
    <agm-clock />
    <agm-hr />
  </div>
</template>

<script>
import AgmClock from "../clock/index.vue";
import AgmHr from "../html/AgmHr.vue";
import { mdiMicrophone, mdiDotsHorizontal } from "@mdi/js";
export default {
  components: {
    AgmClock,
    AgmHr,
  },
  data() {
    return {
      icons: {
        mdiMicrophone,
        mdiDotsHorizontal,
      },
    };
  },
};
</script>

<style lang="scss">
.agm-system-bar {
  margin: 2rem;
}

.agm-top-left-btn {
  position: absolute;
  top: 2rem;
  left: 2rem;
}

.agm-top-right-btn {
  position: absolute;
  top: 2rem;
  right: 2rem;
}
</style>
