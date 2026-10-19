<script setup lang="ts">
import { AgmButton, AgmToast } from 'augma'
import { computed, nextTick, shallowRef } from 'vue'

const messages = {
  success: { title: 'Settings saved', description: 'Your new display preferences are in effect.' },
  warning: { title: 'Low battery', description: 'Connect to power to keep going.' },
  danger: { title: 'Sync incomplete', description: 'Check your network connection and try again.' },
  neutral: { title: 'Preview mode', description: 'Actions here only affect this local example.' },
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
    <AgmButton @click="show('success')">Save settings</AgmButton>
    <AgmButton variant="outline" @click="show('warning')">Show warning</AgmButton>
    <AgmButton variant="outline" @click="show('danger')">Simulate failure</AgmButton>
    <AgmButton variant="ghost" @click="show('neutral')">Show message</AgmButton>
    <AgmToast
      v-model:open="open"
      :tone="tone"
      :title="message.title"
      :description="message.description"
      close-label="Close notification"
      region-label="Notifications (F8)"
    />
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
