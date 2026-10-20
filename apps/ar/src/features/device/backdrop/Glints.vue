<script setup lang="ts">
/** Four-pointed sparkles that flash now and then: `[x %, y %, size px, delay s]`. */
defineProps<{ points: number[][] }>()
</script>

<template>
  <div class="glints">
    <i v-for="([x, y, size, delay], index) in points" :key="index" class="glint" :style="{ left: `${x}%`, top: `${y}%`, width: `${size}px`, animationDelay: `${delay}s` }" />
  </div>
</template>

<style scoped>
.glints { position: absolute; inset: 0; }
.glint { position: absolute; aspect-ratio: 1; translate: -50% -50%; transform: scale(0); clip-path: polygon(50% 0, 56% 44%, 100% 50%, 56% 56%, 50% 100%, 44% 56%, 0 50%, 44% 44%); background: radial-gradient(circle closest-side, white 20%, rgb(var(--glint, 255 255 255) / 70%) 60%, transparent); animation: glint 7s ease-in-out infinite; will-change: transform; }
@keyframes glint { 0%, 74%, 100% { transform: scale(0) rotate(0); } 82% { transform: scale(1) rotate(45deg); } 90% { transform: scale(.35) rotate(90deg); } }
</style>
