<template>
  <div class="agm-system-bar">
    <audio-btn class="agm-top-left-btn" />
    <agm-button icon class="agm-top-right-btn">
      <agm-icon :icon="icons.mdiDotsHorizontal"></agm-icon>
    </agm-button>
    <agm-clock />
    <agm-hr />
  </div>
</template>

<script>
import { mdiDotsHorizontal } from "@mdi/js";
import AudioBtn from "../menu/AudioBtn.vue";
export default {
  components: { AudioBtn },
  data() {
    return {
      icons: {
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
