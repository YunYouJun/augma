<script lang="ts" setup>
import { ref } from 'vue'
import AgmButton from '../button/src/index.vue'
import AgmDialog from './src/index.vue'

const dialogVisible = ref(false)
</script>

<template>
  <AgmButton type="primary" @click="dialogVisible = !dialogVisible">
    点击打开 Dialog
  </AgmButton>
  <AgmDialog v-model="dialogVisible">
    <template #header>
      标题
    </template>
    这是一段信息
  </AgmDialog>
</template>
