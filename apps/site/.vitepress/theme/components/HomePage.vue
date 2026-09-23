<script setup lang="ts">
import AiBand from './AiBand.vue'
import ComponentStrip from './ComponentStrip.vue'
import DevicePreview from './DevicePreview.vue'
import UiIcon from './UiIcon.vue'
</script>

<template>
  <div class="augma-home">
    <section class="hero-shell">
      <div class="hero">
        <div class="hero-copy">
          <h1>
            Augma
            <span aria-hidden="true">/</span>
          </h1>
          <h2>界面，浮现于现实。</h2>
          <p>为 Web 构建轻盈的 AR 风格界面。</p>
          <div class="hero-actions">
            <a class="agm-button agm-button--primary" href="/components/">
              浏览组件
              <UiIcon name="arrow" />
            </a>
            <a
              class="agm-button agm-button--outline"
              href="/ar/"
              data-no-router
            >
              <UiIcon name="scan" />
              体验 AR
            </a>
          </div>
        </div>
        <DevicePreview />
      </div>
    </section>
    <div class="home-content">
      <ComponentStrip />
      <AiBand />
      <footer class="home-footer">
        <span>Augma · MIT</span>
        <a href="/guide/">为你的下一个界面，Link Start.</a>
      </footer>
    </div>
  </div>
</template>
