<script setup lang="ts">
import type { DeviceNotice } from './types'
import { AgmButton } from 'augma'
import DeviceIcon from './DeviceIcon.vue'

defineProps<{ notices: readonly DeviceNotice[] }>()
const emit = defineEmits<{ clear: [] }>()
</script>

<template>
  <div class="feature-body">
    <p class="notification-note">设备操作记录仅保留在本次体验中。</p>
    <ol v-if="notices.length" class="notice-list">
      <li v-for="notice in notices" :key="notice.id"><div><h3>{{ notice.title }}</h3><time>{{ notice.time }}</time></div><p>{{ notice.detail }}</p></li>
    </ol>
    <div v-else class="empty-notices"><DeviceIcon name="notifications" /><h3>通知已清空</h3><p>扫描空间或开始导航后，新的操作记录会出现在这里。</p></div>
    <AgmButton v-if="notices.length" variant="outline" class="full-button" @click="emit('clear')">清空通知</AgmButton>
  </div>
</template>

<style scoped>
.notification-note { font-size: 12px; color: var(--agm-muted); margin: 0 0 18px; line-height: 1.7; }
.notice-list { list-style: none; padding: 0; margin: 0 0 18px; max-height: 410px; overflow-y: auto; }
.notice-list li { border-left: 2px solid var(--agm-cyan); padding: 0 0 16px 14px; margin: 0 0 20px; border-bottom: 1px solid var(--agm-border); }
.notice-list li > div { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
.notice-list h3 { font-size: 14px; font-weight: 500; margin: 0; }
.notice-list time { font-size: 11px; color: var(--agm-muted); }
.notice-list p { font-size: 12px; line-height: 1.8; color: var(--agm-muted); margin: 8px 0 0; }
.empty-notices { padding: 60px 10px; text-align: center; }
.empty-notices svg { width: 36px; height: 36px; color: var(--agm-muted); }
.empty-notices h3 { font-size: 18px; font-weight: 500; }
.empty-notices p { font-size: 13px; line-height: 1.8; color: var(--agm-muted); }
</style>
