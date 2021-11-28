<template>
  <agm-card color="#e5bb63" dark>
    <div class="weather-logo">
      <AgmIcon style="transform: scale(3)">
        <i-mdi-weather-partly-cloudy />
      </AgmIcon>
    </div>
    <div class="weather-info">
      <div class="weather-city">
        {{ city }}
      </div>
      <div class="weather-temperature">
        {{ temperature }}
      </div>
    </div>
  </agm-card>
</template>

<script lang="ts" setup>
const city = ref('北京市')
const temperature = ref('-3°C')
</script>

<style lang="scss">
.weather-logo {
  display: inline-flex;
  padding: 1.5rem 3rem;
  justify-content: center;
  align-items: center;
}
.weather-info {
  padding: 0.5rem 1rem;
  display: flex;
  flex-direction: column;
  line-height: 1;
  align-items: center;
  gap: 0.5rem;
  background: #d1ac6a;
}
.weather-city {
  display: inline-flex;
  border: 1px solid currentColor;
  border-radius: 4px;
  padding: 4px 6px;
}
.weather-temperature {
  display: inline-flex;
  font-size: 2.5rem;
}
</style>
