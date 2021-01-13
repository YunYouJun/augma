<template>
  <material-icon v-if="type === 'mdi'" :icon="icon"></material-icon>
  <iconfont v-else :icon="icon"></iconfont>
</template>

<script>
import MaterialIcon from "./MaterialIcon.vue";
import Iconfont from "./iconfont.vue";
export default {
  name: "AgmIcon",
  components: {
    Iconfont,
    MaterialIcon,
  },
  props: {
    icon: String,
    type: {
      type: String,
      default: "mdi",
    },
  },
};
</script>

<style lang="scss">
.agm-icon {
  &-success {
    color: var(--agm-success);
  }

  &-error {
    color: var(--agm-error);
  }

  &-warning {
    color: var(--agm-warning);
  }

  &-info {
    color: var(--agm-info);
  }
}
</style>
