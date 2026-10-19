<script setup lang="ts">
import { useI18n } from '../i18n'
import CopyCommand from './CopyCommand.vue'
import UiIcon from './UiIcon.vue'

const { t, link } = useI18n()
</script>

<template>
  <section class="ai-band reveal">
    <div>
      <h2>{{ t('ai.title') }}</h2>
      <p>{{ t('ai.lead') }}</p>
    </div>
    <CopyCommand text="npx skills add YunYouJun/augma --skill augma" />
    <a :href="link('/ai/')">
      {{ t('ai.guide') }}
      <UiIcon name="arrow" />
    </a>
  </section>
</template>
