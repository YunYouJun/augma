<script lang="ts" setup>
import { AgmTypeArray } from '@augma/utils'
import './index.scss'
</script>

<template>
  <div class="dark-bg">
    <hr class="agm-hr">
  </div>

  <table class="agm-table">
    <thead>
      <tr>
        <td>表格</td>
        <td>类型</td>
        <td>测试</td>
      </tr>
    </thead>
    <tbody>
      <tr v-for="(type, i) in AgmTypeArray" :key="i">
        <td>
          {{ type }}
        </td>
        <td>
          {{ type }}
        </td>
        <td>
          {{ type }}
        </td>
      </tr>
    </tbody>
  </table>
</template>

<style lang="scss">
.dark-bg {
  background: gray;
  padding: 1rem;
}
</style>
