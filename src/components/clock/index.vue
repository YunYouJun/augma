<template>
  <span class="agm-clock">{{ now }}</span>
</template>

<script>
export default {
  data() {
    return {
      hour: "14",
      minute: "59",
    };
  },
  computed: {
    now() {
      const addZero = this.minute.toString().length === 1;
      const minute = (addZero ? "0" : "") + this.minute;
      return this.hour + ":" + minute;
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
