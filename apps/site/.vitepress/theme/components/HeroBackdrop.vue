<script setup lang="ts">
import { onMounted, shallowRef } from 'vue'
import { heroBackdrop } from '../media'

// Static image first (SSR and reduced motion); the loop only starts after mount.
const playVideo = shallowRef(false)
const failed = shallowRef(false)
onMounted(() => {
  playVideo.value = !!heroBackdrop.video && !matchMedia('(prefers-reduced-motion: reduce)').matches
})
</script>

<template>
  <div class="hero-backdrop" :class="{ 'is-fallback': failed }" aria-hidden="true">
    <video
      v-if="playVideo"
      :src="heroBackdrop.video"
      :poster="heroBackdrop.image"
      autoplay
      muted
      loop
      playsinline
      @error="playVideo = false"
    />
    <img
      v-else-if="!failed"
      :src="heroBackdrop.image"
      alt=""
      decoding="async"
      @error="failed = true"
    >
  </div>
</template>
