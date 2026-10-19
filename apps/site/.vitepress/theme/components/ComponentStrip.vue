<script setup lang="ts">
import {
  AgmButton,
  AgmHudGauge,
  AgmHudStatus,
  AgmIconButton,
  AgmPanel,
  AgmSlider,
  AgmSwitch,
  AgmToast,
} from 'augma'
import { shallowRef } from 'vue'
import { useI18n } from '../i18n'

const { t, link } = useI18n()

const visible = shallowRef(true)
const opacity = shallowRef(72)
const locked = shallowRef(false)
const notification = shallowRef(false)
</script>

<template>
  <section class="component-strip">
    <h2 class="reveal">{{ t('strip.title') }}</h2>
    <div class="component-columns">
      <div class="component-column reveal">
        <h3>
          <a :href="link('/components/button')">{{ t('strip.actions') }}</a>
        </h3>
        <p>{{ t('strip.actionsLead') }}</p>
        <div class="button-samples">
          <AgmButton @click="notification = true">{{ t('strip.primary') }}</AgmButton>
          <AgmButton variant="outline" @click="notification = true">
            {{ t('strip.secondary') }}
          </AgmButton>
          <AgmButton variant="ghost" @click="notification = true">
            {{ t('strip.ghost') }}
          </AgmButton>
          <AgmIconButton :label="t('strip.notify')" @click="notification = true" />
        </div>
      </div>
      <div class="component-column reveal">
        <h3>
          <a :href="link('/components/switch')">{{ t('strip.controls') }}</a>
        </h3>
        <p>{{ t('strip.controlsLead') }}</p>
        <div class="settings-fields">
          <AgmSwitch v-model="visible" :label="t('preview.showHud')" />
          <AgmSlider v-model="opacity" :label="t('preview.opacity')" :min="20" />
          <AgmSwitch v-model="locked" :label="t('strip.anchor')" />
        </div>
      </div>
      <div class="component-column reveal">
        <h3>
          <a :href="link('/components/panel')">{{ t('strip.info') }}</a>
        </h3>
        <p>{{ t('strip.infoLead') }}</p>
        <div class="mini-hud-space">
          <AgmPanel
            v-if="visible"
            class="mini-hud"
            :style="{ opacity: opacity / 100 }"
          >
            <AgmHudStatus>
              {{ locked ? t('strip.anchored') : t('strip.ready') }}
            </AgmHudStatus>
            <AgmHudGauge :label="t('preview.opacity')" :value="opacity" />
            <p>{{ t('strip.blend') }}</p>
            <a :href="link('/components/hud-progress')">{{ t('strip.exploreHud') }}</a>
          </AgmPanel>
          <p v-else class="hidden-hud">{{ t('strip.hidden') }}</p>
        </div>
      </div>
    </div>
    <AgmToast
      v-model:open="notification"
      :title="t('strip.toastTitle')"
      :description="t('strip.toastDescription')"
    />
  </section>
</template>
