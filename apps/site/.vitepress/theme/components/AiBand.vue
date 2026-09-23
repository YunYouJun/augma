<script setup lang="ts">
import CopyCommand from './CopyCommand.vue'
import UiIcon from './UiIcon.vue'
</script>

<template>
  <section class="ai-band">
    <div>
      <h2>AI 也能读懂的设计系统</h2>
      <p>为人，也为 AI，提供清晰、可组合的界面语言。</p>
    </div>
    <CopyCommand text="npx skills add YunYouJun/augma --skill augma" />
    <a href="/ai/">
      AI 接入指南
      <UiIcon name="arrow" />
    </a>
  </section>
</template>
