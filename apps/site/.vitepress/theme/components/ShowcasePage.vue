<script setup lang="ts">
import { useI18n } from '../i18n'
import DemoPreview from './DemoPreview.vue'
import UiIcon from './UiIcon.vue'

const { t, link } = useI18n()
</script>

<template>
  <div class="showcase-page">
    <div class="showcase-heading">
      <h1>{{ t('showcase.title') }}</h1>
      <p>{{ t('showcase.lead') }}</p>
      <a :href="link('/components/')">{{ t('showcase.all') }}</a>
    </div>
    <section class="simulator-entry hud-brackets agm-materialize">
      <div>
        <h2>{{ t('showcase.simulatorTitle') }}</h2>
        <p>{{ t('showcase.simulatorLead') }}</p>
        <a class="agm-button agm-button--primary" href="/ar/" target="_self"><UiIcon name="scan" />{{ t('showcase.openSimulator') }}</a>
      </div>
      <div class="simulator-features"><span>{{ t('showcase.scan') }}</span><span>{{ t('showcase.route') }}</span><span>{{ t('showcase.sound') }}</span><span>{{ t('showcase.notifications') }}</span><small>{{ t('showcase.noCamera') }}</small></div>
    </section>
    <section class="composition-gallery">
      <h2>{{ t('showcase.compositions') }}</h2>
      <p>{{ t('showcase.compositionsLead') }}</p>
      <h3>{{ t('showcase.controlPanel') }}</h3>
      <DemoPreview name="control-panel" group="compositions" />
      <h3>{{ t('showcase.hud') }}</h3>
      <DemoPreview name="hud" group="compositions" />
      <h3>{{ t('showcase.theme') }}</h3>
      <DemoPreview name="theme" group="compositions" />
    </section>
  </div>
</template>

<style scoped>
.simulator-entry { display: grid; grid-template-columns: 1.5fr 1fr; gap: 48px; padding: 36px; margin: 28px 0 44px; border: 1px solid var(--agm-border); border-left: 3px solid var(--agm-accent); background: var(--agm-panel); }
.simulator-entry h2 { font-size: 27px; font-weight: 500; margin: 0 0 14px; }
.simulator-entry p { font-size: 14px; color: var(--agm-muted); line-height: 1.8; margin: 0 0 24px; }
.simulator-entry svg { width: 20px; height: 20px; }
.simulator-features { display: grid; grid-template-columns: 1fr 1fr; align-content: center; gap: 24px; font-size: 14px; }
.simulator-features span { border-bottom: 1px solid var(--agm-border); padding-bottom: 12px; }
.simulator-features small { grid-column: 1 / -1; color: var(--agm-muted); font-size: 12px; }
@media (max-width: 700px) { .simulator-entry { grid-template-columns: 1fr; gap: 26px; padding: 24px; } }
</style>
