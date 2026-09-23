<script setup lang="ts">
import { AgmButton, AgmToast } from 'augma'
import { shallowRef } from 'vue'

const open = shallowRef(false)
</script>

<template>
  <div>
    <AgmButton @click="open = true">保存设置</AgmButton>
    <AgmToast
      v-model:open="open"
      title="设置已保存"
      description="新的显示偏好已生效。"
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
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
