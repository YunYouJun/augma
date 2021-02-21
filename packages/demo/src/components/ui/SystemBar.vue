<template>
  <div class="agm-system-bar">
    <audio-btn class="agm-top-left-btn" />
    <menu-btn class="agm-top-right-btn" />
    <agm-clock />
    <hr class="agm-hr" />
  </div>
</template>

<script>
import AudioBtn from "../menu/AudioBtn.vue";
import MenuBtn from "../menu/MenuBtn.vue";
export default {
  components: { AudioBtn, MenuBtn },
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
