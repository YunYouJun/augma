<script setup lang="ts">
import type { MessageKey } from '../i18n/zh-CN'
import { AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
import { computed } from 'vue'
import { version } from '../../../../../packages/augma/package.json'
import { components, origin } from '../../../../../scripts/catalog.mjs'
import { useI18n } from '../i18n'
import { useLinkStart } from '../linkStart'
import CopyCommand from './CopyCommand.vue'
import HeroBackdrop from './HeroBackdrop.vue'
import HudOrbit from './HudOrbit.vue'
import UiIcon from './UiIcon.vue'

const { t, link } = useI18n()
const onLinkStart = useLinkStart()
const repo = 'https://github.com/YunYouJun/augma'
// The release workflow attaches the app under a fixed name, so "latest" always resolves.
const macZip = `${repo}/releases/latest/download/Augma-macOS.zip`
const count = components.length

const checks = computed(() => [
  t('download.checkNpm', { version }),
  t('download.checkMac'),
  t('download.checkAr'),
  t('download.checkDocs', { count }),
])
const steps: MessageKey[] = ['download.step1', 'download.step2', 'download.step3']
const features: { icon: 'layers' | 'motion' | 'scan' | 'monitor' | 'globe' | 'sparkles', title: MessageKey, text: MessageKey }[] = [
  { icon: 'layers', title: 'download.newComponents', text: 'download.newComponentsText' },
  { icon: 'motion', title: 'download.newMotion', text: 'download.newMotionText' },
  { icon: 'scan', title: 'download.newAr', text: 'download.newArText' },
  { icon: 'monitor', title: 'download.newMac', text: 'download.newMacText' },
  { icon: 'globe', title: 'download.newI18n', text: 'download.newI18nText' },
  { icon: 'sparkles', title: 'download.newAi', text: 'download.newAiText' },
]
</script>

<template>
  <div class="augma-download">
    <section class="hero-shell">
      <HeroBackdrop />
      <div class="hero-field" aria-hidden="true" />
      <div class="download-hero">
        <div class="download-copy">
          <p class="download-eyebrow" style="--i: 0">
            <AgmHudStatus>{{ t('download.eyebrow', { version }) }}</AgmHudStatus>
          </p>
          <h1 style="--i: 1">
            {{ t('download.title') }}
          </h1>
          <p class="download-lead" style="--i: 2">
            {{ t('download.lead') }}
          </p>
          <div class="download-actions" style="--i: 3">
            <a class="agm-button agm-button--primary" :href="macZip">
              <UiIcon name="download" />
              {{ t('download.mac') }}
            </a>
            <a class="agm-button agm-button--outline" href="#get" target="_self" @click="onLinkStart">
              {{ t('download.start') }}
              <UiIcon name="arrow" />
            </a>
          </div>
          <div class="download-install" style="--i: 4">
            <CopyCommand text="pnpm add augma" />
          </div>
        </div>
        <div class="download-console">
          <HudOrbit />
          <AgmPanel class="console-panel agm-materialize" :title="t('download.console')" style="--agm-delay: 260ms">
            <div class="console-body">
              <ol class="console-checks">
                <li v-for="(check, index) in checks" :key="index" :style="{ '--i': index }">
                  <AgmHudStatus>{{ check }}</AgmHudStatus>
                </li>
              </ol>
              <AgmHudProgress :label="t('download.ready')" :value="100" variant="ring" />
            </div>
          </AgmPanel>
        </div>
      </div>
    </section>

    <div class="download-content">
      <section id="get" class="download-section" aria-labelledby="download-choose">
        <h2 id="download-choose" class="reveal">
          {{ t('download.choose') }}
        </h2>
        <div class="download-cards">
          <article class="download-card hud-brackets reveal">
            <h3><UiIcon name="package" />{{ t('download.webTitle') }}</h3>
            <p>{{ t('download.webLead') }}</p>
            <CopyCommand text="pnpm add augma" />
            <p class="download-note">
              {{ t('download.webCore') }}
            </p>
            <CopyCommand :text="`pnpm dlx shadcn-vue@2.8.2 add ${origin}/r/button.json`" />
            <div class="download-links">
              <a :href="link('/guide/')">{{ t('download.webGuide') }}</a>
              <a :href="link('/ai/')">{{ t('download.webRegistry') }}</a>
            </div>
          </article>
          <article class="download-card is-featured hud-brackets reveal">
            <h3><UiIcon name="monitor" />{{ t('download.macTitle') }}</h3>
            <p>{{ t('download.macLead') }}</p>
            <a class="agm-button agm-button--primary" :href="macZip">
              <UiIcon name="download" />
              {{ t('download.mac') }}
            </a>
            <p class="download-meta">
              {{ t('download.macMeta', { version }) }}
            </p>
            <div class="download-links">
              <a :href="`${macZip}.sha256`">{{ t('download.macChecksum') }}</a>
              <a :href="`${repo}/releases`">{{ t('download.macReleases') }}</a>
              <a :href="link('/guide/macos')">{{ t('download.macGuide') }}</a>
            </div>
          </article>
          <article class="download-card hud-brackets reveal">
            <h3><UiIcon name="scan" />{{ t('download.arTitle') }}</h3>
            <p>{{ t('download.arLead') }}</p>
            <a class="agm-button agm-button--outline" href="/ar/" target="_self">
              <UiIcon name="scan" />
              {{ t('download.arOpen') }}
            </a>
            <p class="download-meta">
              {{ t('download.arMeta') }}
            </p>
            <div class="download-links">
              <a :href="link('/guide/ar')">{{ t('download.arGuide') }}</a>
            </div>
          </article>
        </div>
      </section>

      <section class="download-section" aria-labelledby="download-first-open">
        <h2 id="download-first-open" class="reveal">
          {{ t('download.firstOpen') }}
        </h2>
        <p class="download-section-lead reveal">
          {{ t('download.firstOpenLead') }}
        </p>
        <ol class="first-open-steps">
          <li v-for="step in steps" :key="step" class="reveal">
            {{ t(step) }}
          </li>
        </ol>
      </section>

      <section class="download-section" aria-labelledby="download-new">
        <h2 id="download-new" class="reveal">
          {{ t('download.whatsNew') }}
        </h2>
        <ul class="download-features">
          <li v-for="feature in features" :key="feature.title" class="reveal">
            <UiIcon :name="feature.icon" />
            <strong>{{ t(feature.title, { count }) }}</strong>
            <span>{{ t(feature.text) }}</span>
          </li>
        </ul>
      </section>

      <footer class="download-footer">
        <span>Augma {{ version }} · MIT</span>
        <nav>
          <a :href="`${repo}/releases/tag/v${version}`">{{ t('download.notes') }}</a>
          <a :href="`${repo}/blob/main/CHANGELOG.md`">{{ t('download.changelog') }}</a>
          <a :href="link('/guide/migration')">{{ t('download.migration') }}</a>
        </nav>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.download-hero {
  max-width: 1248px;
  min-height: 500px;
  margin: auto;
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, 1fr);
  align-items: center;
  gap: 40px;
  padding: 28px 0 36px;
}
.download-copy > * {
  animation: hero-rise 760ms var(--agm-ease) calc(var(--i, 0) * 90ms) backwards;
}
.download-eyebrow {
  margin: 0;
  font-size: 13px;
}
.download-copy h1 {
  margin: 14px 0 16px;
  font: 600 clamp(46px, 5.2vw, 76px) / 1.05 var(--agm-font);
  letter-spacing: -0.04em;
}
.download-lead {
  max-width: 30em;
  margin: 0 0 26px;
  color: var(--agm-muted);
  font-size: 18px;
  line-height: 1.6;
}
.download-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
}
.download-actions .agm-button {
  min-height: 50px;
}
.download-actions svg,
.download-card .agm-button svg {
  width: 20px;
  height: 20px;
}
.download-install {
  max-width: 338px;
  margin-top: 22px;
}
.download-install .copy-command {
  width: 100%;
}
.download-console {
  --agm-progress-color: var(--agm-highlight);
  position: relative;
  display: grid;
  place-items: center;
  min-height: 420px;
  perspective: 900px;
}
.console-panel {
  width: 100%;
  max-width: 400px;
  background: color-mix(in srgb, var(--agm-bg) 86%, transparent);
  -webkit-backdrop-filter: blur(14px) saturate(1.1);
  backdrop-filter: blur(14px) saturate(1.1);
}
.console-body {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
}
.console-checks {
  display: grid;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
  font-size: 13px;
}
/* The checks report in one by one after the panel has materialized. */
.console-checks li {
  animation: console-line 480ms var(--agm-ease) calc(760ms + var(--i) * 240ms) backwards;
}
.console-panel .agm-progress--ring {
  flex-shrink: 0;
  width: 116px;
}
/* The console is shorter than the home device panel, so keep the radar sweep faint. */
.download-console :deep(.hud-orbit-sweep) {
  opacity: 0.5;
}
.download-content {
  max-width: 1248px;
  margin: auto;
  padding-bottom: 12px;
}
.download-section {
  padding: 52px 0 8px;
}
.download-section > h2 {
  margin: 0 0 22px;
  font-size: 29px;
  font-weight: 500;
  line-height: 1.5;
}
.download-section-lead {
  max-width: 44em;
  margin: -10px 0 24px;
  color: var(--agm-muted);
  font-size: 14px;
  line-height: 1.8;
}
.download-cards {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 24px;
}
.download-card {
  display: grid;
  align-content: start;
  gap: 14px;
  min-width: 0;
  padding: 28px;
  border: 1px solid var(--agm-border);
  border-radius: 3px;
  background: var(--agm-panel);
  box-shadow:
    var(--agm-shadow),
    inset 0 1px 0 var(--agm-light);
}
.download-card.is-featured {
  border-top: 2px solid var(--agm-accent);
}
.download-card.hud-brackets::before {
  opacity: 0;
  inset: -12px;
}
.download-card:hover::before,
.download-card:focus-within::before {
  opacity: 1;
  inset: -6px;
}
.download-card h3 {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0;
  font-size: 20px;
  font-weight: 500;
}
.download-card h3 svg {
  width: 24px;
  height: 24px;
  color: var(--agm-highlight);
}
.download-card p {
  margin: 0;
  color: var(--agm-muted);
  font-size: 14px;
  line-height: 1.7;
}
.download-card .agm-button {
  justify-self: start;
  max-width: 100%;
}
.download-card .copy-command {
  min-width: 0;
}
.download-card .download-note {
  font-size: 12px;
}
.download-meta {
  font-size: 12px !important;
  font-variant-numeric: tabular-nums;
}
.download-links,
.download-footer nav {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 18px;
  font-size: 13px;
}
.download-links a,
.download-footer a {
  color: var(--agm-cyan);
}
.download-links a:hover,
.download-footer a:hover {
  color: var(--agm-accent);
}
.first-open-steps {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 20px;
  margin: 0;
  padding: 0;
  list-style: none;
  counter-reset: step;
}
.first-open-steps li {
  position: relative;
  padding: 18px 20px 20px 66px;
  border-left: 2px solid var(--agm-accent);
  background: var(--agm-surface);
  font-size: 14px;
  line-height: 1.7;
  counter-increment: step;
}
.first-open-steps li::before {
  content: counter(step, decimal-leading-zero);
  position: absolute;
  top: 16px;
  left: 18px;
  color: var(--agm-highlight);
  font: 600 26px / 1 var(--agm-font);
  font-variant-numeric: tabular-nums;
}
.download-features {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1px;
  margin: 0;
  padding: 0;
  list-style: none;
  border: 1px solid var(--agm-border);
  background: var(--agm-border);
}
.download-features li {
  display: grid;
  gap: 6px;
  padding: 24px;
  background: var(--agm-bg);
}
.download-features svg {
  width: 26px;
  height: 26px;
  margin-bottom: 6px;
  color: var(--agm-highlight);
}
.download-features strong {
  font-size: 16px;
  font-weight: 500;
}
.download-features span {
  color: var(--agm-muted);
  font-size: 13px;
  line-height: 1.7;
}
.download-footer {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 16px;
  margin-top: 52px;
  padding: 20px 0 26px;
  border-top: 1px solid var(--agm-border);
  color: var(--agm-muted);
  font-size: 12px;
}
@keyframes console-line {
  from {
    opacity: 0;
    translate: -10px 0;
  }
}
@media (max-width: 1320px) {
  .download-hero,
  .download-content {
    margin-inline: 40px;
  }
}
@media (max-width: 900px) {
  .download-hero {
    grid-template-columns: minmax(0, 1fr);
    gap: 8px;
    padding-top: 36px;
  }
  .download-cards,
  .first-open-steps {
    grid-template-columns: minmax(0, 1fr);
  }
  .download-features {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
@media (max-width: 700px) {
  .download-hero,
  .download-content {
    margin-inline: 24px;
  }
  .download-lead {
    font-size: 16px;
  }
  .download-console {
    min-height: 380px;
  }
  .console-body {
    flex-direction: column;
    align-items: flex-start;
  }
  .download-features {
    grid-template-columns: minmax(0, 1fr);
  }
  .download-card {
    padding: 22px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .download-copy > *,
  .console-checks li {
    animation: none;
  }
}
</style>
