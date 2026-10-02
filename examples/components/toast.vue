<script setup lang="ts">
import { AgmButton, AgmToast } from 'augma'
import { computed, nextTick, shallowRef } from 'vue'

const messages = {
  success: { title: '设置已保存', description: '新的显示偏好已生效。' },
  warning: { title: '电量较低', description: '请连接电源后继续使用。' },
  danger: { title: '同步未完成', description: '请检查网络连接后重试。' },
  neutral: { title: '预览模式', description: '当前操作只影响本地示例。' },
}
const open = shallowRef(false)
const tone = shallowRef<keyof typeof messages>('success')
const message = computed(() => messages[tone.value])

async function show(nextTone: keyof typeof messages) {
  open.value = false
  await nextTick()
  tone.value = nextTone
  open.value = true
}
</script>

<template>
  <div class="example-row">
    <AgmButton @click="show('success')">保存设置</AgmButton>
    <AgmButton variant="outline" @click="show('warning')">显示提醒</AgmButton>
    <AgmButton variant="outline" @click="show('danger')">模拟失败</AgmButton>
    <AgmButton variant="ghost" @click="show('neutral')">显示消息</AgmButton>
    <AgmToast v-model:open="open" :tone="tone" :title="message.title" :description="message.description" />
  </div>
</template>

<style scoped>
.example-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
}
</style>
