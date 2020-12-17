<template>
  <transition name="agm-notification-fade">
    <div class="agm-notification">
      <i class="agm-notification__icon"></i>
    </div>
  </transition>
</template>

<script lang="ts">
import { defineComponent, PropType, ref } from "vue";
export default defineComponent({
  name: "AgmNotification",
  props: {
    duration: {
      type: Number,
      default: 5000,
    },
    position: {
      type: String as PropType<"top-right">,
      default: "top-right",
    },
    showClose: {
      type: Boolean,
      default: true,
    },
  },
  setup(props) {
    const visible = ref(false);
    const closed = ref(false);
    const timer = ref(null);

    return {
      visible,
      closed,
      timer,
    };
  },
  methods: {
    startTimer() {
      if (this.duration > 0) {
        this.timer = setTimeout(() => {
          if (this.closed) {
            this.close();
          }
        }, this.duration);
      }
    },
    clearTimer() {
      clearTimeout(this.timer);
    },
    close() {
      this.closed = true;
      this.timer = null;
    },
  },
});
</script>

<style lang="scss">
@import "../../scss/variables/index.scss";
.agm-notification {
  display: flex;
  width: 8rem;
  height: 3rem;
  position: fixed;
  background-color: white;
  box-shadow: $box-shadow-light;
}
</style>
