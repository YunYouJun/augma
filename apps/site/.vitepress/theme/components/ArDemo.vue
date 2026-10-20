<script setup lang="ts">
import { onMounted, shallowRef } from 'vue'
import { useI18n } from '../i18n'
import { arDemo } from '../media'
import UiIcon from './UiIcon.vue'

const { t, link } = useI18n()

// Reduced motion keeps the poster with manual controls instead of autoplay.
const autoplay = shallowRef(false)
onMounted(() => {
  autoplay.value = !matchMedia('(prefers-reduced-motion: reduce)').matches
})
</script>

<template>
  <section class="ar-demo" aria-labelledby="ar-demo-title">
    <div class="ar-demo-copy reveal">
      <h2 id="ar-demo-title">{{ t('arDemo.title') }}</h2>
      <p>{{ t('arDemo.lead') }}</p>
      <div class="ar-demo-actions">
        <a class="agm-button agm-button--primary" href="/ar/" target="_self">
          <UiIcon name="scan" />
          {{ t('arDemo.open') }}
        </a>
        <a class="agm-button agm-button--outline" :href="link('/download')">
          <UiIcon name="download" />
          {{ t('arDemo.mac') }}
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
        :aria-label="t('arDemo.video')"
      >
        <source :src="arDemo.webm" type="video/webm">
        <source :src="arDemo.mp4" type="video/mp4">
      </video>
    </div>
  </section>
</template>
