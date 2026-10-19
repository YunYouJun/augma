<script setup lang="ts">
import { version } from '../../../../../packages/augma/package.json'
import { components } from '../../../../../scripts/catalog.mjs'
import { useI18n } from '../i18n'
import AiBand from './AiBand.vue'
import ArDemo from './ArDemo.vue'
import ComponentStrip from './ComponentStrip.vue'
import CopyCommand from './CopyCommand.vue'
import DevicePreview from './DevicePreview.vue'
import HeroBackdrop from './HeroBackdrop.vue'
import UiIcon from './UiIcon.vue'

const { t, link } = useI18n()
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
          <h2 style="--i: 1">{{ t('home.tagline') }}</h2>
          <p style="--i: 2">{{ t('home.lead') }}</p>
          <div class="hero-actions" style="--i: 3">
            <a class="agm-button agm-button--primary" :href="link('/components/')">
              {{ t('home.browse') }}
              <UiIcon name="arrow" />
            </a>
            <a
              class="agm-button agm-button--outline"
              href="/ar/"
              target="_self"
            >
              <UiIcon name="scan" />
              {{ t('home.tryAr') }}
            </a>
          </div>
          <div class="hero-install" style="--i: 4">
            <CopyCommand text="pnpm add augma" />
            <small>{{ release }} · {{ t('home.componentCount', { count: components.length }) }} · MIT</small>
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
        <a :href="link('/guide/')">{{ t('home.footer') }}</a>
      </footer>
    </div>
  </div>
</template>
