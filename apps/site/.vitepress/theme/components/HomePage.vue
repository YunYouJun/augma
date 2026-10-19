<script setup lang="ts">
import { version } from '../../../../../packages/augma/package.json'
import { components } from '../../../../../scripts/catalog.mjs'
import AiBand from './AiBand.vue'
import ArDemo from './ArDemo.vue'
import ComponentStrip from './ComponentStrip.vue'
import CopyCommand from './CopyCommand.vue'
import DevicePreview from './DevicePreview.vue'
import HeroBackdrop from './HeroBackdrop.vue'
import UiIcon from './UiIcon.vue'

const release = `v${version.split('.').slice(0, 2).join('.')}`
</script>

<template>
  <div class="augma-home">
    <section class="hero-shell">
      <HeroBackdrop />
      <div class="hero-field" aria-hidden="true" />
      <div class="hero">
        <div class="hero-copy">
          <h1 style="--i: 0">
            Augma
            <span aria-hidden="true">/</span>
          </h1>
          <h2 style="--i: 1">界面，浮现于现实。</h2>
          <p style="--i: 2">为 Web 构建轻盈的 AR 风格界面。</p>
          <div class="hero-actions" style="--i: 3">
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
          <div class="hero-install" style="--i: 4">
            <CopyCommand text="pnpm add augma" />
            <small>{{ release }} · {{ components.length }} 个组件 · MIT</small>
          </div>
        </div>
        <DevicePreview />
      </div>
    </section>
    <div class="home-content">
      <ArDemo />
      <ComponentStrip />
      <AiBand />
      <footer class="home-footer">
        <span>Augma · MIT</span>
        <a href="/guide/">为你的下一个界面，Link Start.</a>
      </footer>
    </div>
  </div>
</template>
