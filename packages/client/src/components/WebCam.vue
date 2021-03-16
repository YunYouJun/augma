<template>
  <video ref="videoRef" :class="classes" id="webcam" autoplay></video>
</template>

<script lang="ts">
import { computed, defineComponent, onMounted, ref, watchEffect } from "vue";
import { useWebcam } from "@augma/hooks/useWebcam";
import { useStore } from "vuex";

export default defineComponent({
  props: {
    isFlip: {
      type: Boolean,
      default: false,
    },
    isFront: {
      type: Boolean,
      default: false,
    },
  },
  setup(props) {
    const store = useStore();
    const videoRef = ref(null);

    const isFlip = ref(props.isFlip);

    const classes = computed(() => {
      return {
        flip: isFlip,
      };
    });

    const { changeWebcamStream, settings } = useWebcam(videoRef, {
      isFront: props.isFront,
    });

    watchEffect(async () => {
      await changeWebcamStream(props.isFront);
    });

    onMounted(async () => {
      await changeWebcamStream(props.isFront);
      store.commit("camera/setVideoEl", videoRef.value);
      store.commit("camera/setSettings", settings);
      const ratio = document.body.clientWidth / settings.value.width;
      store.commit("camera/setRatio", ratio);
    });

    return {
      videoRef,
      classes,
      isFlip,
    };
  },
});
</script>

<style lang="scss">
#webcam {
  width: 100vw;
  height: 100vh;
  object-fit: cover;
}

.flip {
  transform: rotateY(180deg);
}
</style>
