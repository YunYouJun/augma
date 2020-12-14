<template>
  <material-icon :icon="icon"></material-icon>
  <!-- <iconfont :icon="icon"></iconfont> -->
</template>

<script>
import MaterialIcon from "./MaterialIcon.vue";
import Iconfont from "./iconfont.vue";
export default {
  components: {
    Iconfont,
    MaterialIcon,
  },
  props: {
    icon: String,
  },
};
</script>
