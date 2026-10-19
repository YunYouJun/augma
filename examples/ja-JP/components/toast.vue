<script setup lang="ts">
import { AgmButton, AgmToast } from 'augma'
import { computed, nextTick, shallowRef } from 'vue'

const messages = {
  success: { title: '設定を保存しました', description: '新しい表示設定が適用されました。' },
  warning: { title: 'バッテリー残量が少なくなっています', description: '電源に接続してからご利用ください。' },
  danger: { title: '同期が完了しませんでした', description: 'ネットワーク接続を確認して、もう一度お試しください。' },
  neutral: { title: 'プレビューモード', description: 'この操作はローカルのサンプルにだけ影響します。' },
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
    <AgmButton @click="show('success')">設定を保存</AgmButton>
    <AgmButton variant="outline" @click="show('warning')">警告を表示</AgmButton>
    <AgmButton variant="outline" @click="show('danger')">失敗をシミュレート</AgmButton>
    <AgmButton variant="ghost" @click="show('neutral')">メッセージを表示</AgmButton>
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
