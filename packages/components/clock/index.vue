<template>
  <span class="agm-clock" :style="styles">{{ now }}</span>
</template>

<script>
import { getAgmVar } from "@augma/shared";

export default {
  name: "AgmClock",
  props: {
    color: {
      type: String,
      default: "",
    },
    addZero: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      hour: "00",
      minute: "00",
    };
  },
  computed: {
    styles() {
      return {
        color: getAgmVar(this.color),
      };
    },
    now() {
      if (this.addZero) {
        const addZeroForH = this.hour.toString().length === 1;
        const hour = (addZeroForH ? "0" : "") + this.hour;
        const addZeroForM = this.minute.toString().length === 1;
        const minute = (addZeroForM ? "0" : "") + this.minute;
        return hour + ":" + minute;
      } else {
        return this.hour + ":" + this.minute;
      }
    },
  },
  mounted() {
    setInterval(() => {
      this.getTime();
    }, 1000);
  },
  methods: {
    getTime() {
      const date = new Date();
      this.hour = date.getHours();
      this.minute = date.getMinutes();
    },
  },
};
</script>

<style lang="scss">
.agm-clock {
  color: white;
  font-size: 1.3rem;
  font-family: sans-serif;
  line-height: 0.9;
}
</style>
