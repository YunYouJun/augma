<script setup lang="ts">
import { onMounted, shallowRef } from 'vue'
import { arDemo } from '../media'
import UiIcon from './UiIcon.vue'

// Reduced motion keeps the poster with manual controls instead of autoplay.
const autoplay = shallowRef(false)
onMounted(() => {
  autoplay.value = !matchMedia('(prefers-reduced-motion: reduce)').matches
})
</script>

<template>
  <section class="ar-demo" aria-labelledby="ar-demo-title">
    <div class="ar-demo-copy reveal">
      <h2 id="ar-demo-title">AR 演示</h2>
      <p>还原自原版 Augma 网页的设备界面。打开天气、扫描空间，再沿路线导航，全程无需摄像头。</p>
      <div class="ar-demo-actions">
        <a class="agm-button agm-button--primary" href="/ar/" data-no-router>
          <UiIcon name="scan" />
          打开 AR 演示
        </a>
        <a class="agm-button agm-button--outline" href="/guide/macos">
          <UiIcon name="download" />
          macOS 客户端
        </a>
      </div>
    </div>
    <div class="ar-demo-media hud-brackets reveal reveal-unfold">
      <video
        :key="String(autoplay)"
        :poster="arDemo.poster"
        :autoplay="autoplay"
        :controls="!autoplay"
        muted
        loop
        playsinline
        :preload="autoplay ? 'auto' : 'none'"
        aria-label="AR 演示录屏：打开天气、空间扫描、开始导航"
      >
        <source :src="arDemo.webm" type="video/webm">
        <source :src="arDemo.mp4" type="video/mp4">
      </video>
    </div>
  </section>
</template>
