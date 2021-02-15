<template>
  <span class="agm-clock" :style="styles">{{ now }}</span>
</template>

<script lang="ts">
import { AgmColorType, getAgmColorByType } from "@augma/shared";
import { defineComponent, PropType } from "vue";

interface DisplayTime {
  hour: number;
  minute: number;
}

export default defineComponent({
  name: "AgmClock",
  props: {
    color: {
      type: String as PropType<AgmColorType>,
      default: "",
    },
    addZero: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return this.getTime();
  },
  computed: {
    styles(): Object {
      return {
        color: getAgmColorByType(this.color),
      };
    },
    now(): string {
      if (this.addZero) {
        const addZeroForH: boolean = this.hour.toString().length === 1;
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
      const { hour, minute } = this.getTime();
      this.hour = hour;
      this.minute = minute;
    }, 1000);
  },
  methods: {
    getTime(): DisplayTime {
      const date = new Date();
      return { hour: date.getHours(), minute: date.getMinutes() };
    },
  },
});
</script>

<style lang="scss">
.agm-clock {
  color: white;
  font-size: 1.3rem;
  font-family: sans-serif;
  line-height: 0.9;
}
</style>
