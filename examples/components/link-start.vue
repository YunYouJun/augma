<script setup lang="ts">
import { AgmButton, AgmHudStatus, linkStart } from 'augma'
import { shallowRef } from 'vue'

const links = shallowRef(0)

// linkStart 铺满屏幕后执行回调，再淡出。实际使用时在回调中调用路由跳转。
function start() {
  return linkStart(() => {
    links.value++
  })
}
</script>

<template>
  <div class="example-row">
    <AgmButton @click="start">Link Start</AgmButton>
    <AgmHudStatus :tone="links ? 'success' : 'neutral'">
      {{ links ? `已连接 ${links} 次` : '等待连接' }}
    </AgmHudStatus>
  </div>
</template>

<style scoped>
.example-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
}
</style>
