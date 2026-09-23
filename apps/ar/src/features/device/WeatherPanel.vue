<script setup lang="ts">
import { shallowRef } from 'vue'
import DeviceIcon from './DeviceIcon.vue'

const city = shallowRef('北京')
const examples = [{ city: '北京', temperature: '-3°C' }, { city: '上海', temperature: '18°C' }, { city: '东京', temperature: '22°C' }]
</script>

<template>
  <div class="weather-widget">
    <div class="weather-symbol"><DeviceIcon name="weather-detail" /></div>
    <div class="weather-info">
      <label class="agm-sr-only" for="weather-city">天气示例城市</label>
      <select id="weather-city" v-model="city" aria-label="天气示例城市"><option v-for="item in examples" :key="item.city" :value="item.city">{{ item.city }}市</option></select>
      <span class="weather-temperature">{{ examples.find(item => item.city === city)?.temperature }}</span>
    </div>
    <p class="weather-note">天气示例 · 非实时数据</p>
  </div>
</template>

<style scoped>
.weather-widget { text-align: center; color: white; }
.weather-symbol { display: flex; align-items: center; justify-content: center; height: 74px; }
.weather-symbol svg { width: 48px; height: 48px; }
.weather-info { display: flex; flex-direction: column; align-items: center; gap: 5px; padding: 8px 16px; background: rgb(209 172 106 / 95%); }
.weather-info select { appearance: none; padding: 3px 6px; font: 16px/1.2 Arial, sans-serif; background: transparent; color: white; border: 1px solid currentColor; border-radius: 4px; cursor: pointer; text-align: center; }
.weather-info option { color: #333; background: white; }
.weather-temperature { font: 40px/1.05 Arial, sans-serif; }
.weather-note { margin: 7px 0 0; font-size: 10px; color: rgb(255 255 255 / 72%); }
</style>
