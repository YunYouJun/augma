<script setup lang="ts">
import { AgmButton, AgmHudStatus, linkStart } from 'augma'
import { shallowRef } from 'vue'

const links = shallowRef(0)

// linkStart は画面を覆ってからコールバックを実行し、フェードアウトします。実際にはルーターの遷移をここで呼びます。
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
      {{ links ? `${links} 回リンク済み` : 'リンク待機中' }}
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
