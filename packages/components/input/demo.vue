<script lang="ts" setup>
import { ref } from 'vue'
import AgmInput from './src/index.vue'

const input = ref('')
</script>

<template>
  <form class="grid gap-4">
    <AgmInput v-model="input" placeholder="请输入内容" />
    <AgmInput
      v-model="input"
      :disabled="true"
      placeholder="禁用状态"
    />
    <AgmInput v-model="input" placeholder="可清空" clearable>
      <!-- <template #suffix> s </template> -->
    </AgmInput>
    <AgmInput v-model="input" placeholder="密码框" show-password />
  </form>
</template>
