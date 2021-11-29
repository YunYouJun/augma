<template>
  <div class="demo-input">
    <agm-input v-model="input" placeholder="请输入内容" />
    <agm-input
      v-model="input"
      :disabled="true"
      placeholder="禁用状态"
    />
    <agm-input v-model="input" placeholder="可清空" clearable>
      <!-- <template #suffix> s </template> -->
    </agm-input>
    <agm-input v-model="input" placeholder="密码框" show-password />
  </div>
</template>

<script lang="ts" setup>
import { ref } from 'vue'
import AgmInput from './src/index.vue'

const input = ref('')
</script>

<style lang="scss">
.demo-input {
  .agm-input {
    margin: 0.5rem 0;
  }
}
</style>
