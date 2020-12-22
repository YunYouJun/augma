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
import { mdiMicrophone, mdiDotsHorizontal } from "@mdi/js";
export default {
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
