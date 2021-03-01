<template>
  <div class="dark-bg">
    <hr class="agm-hr" />
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
      <tr v-for="type in AgmTypeArray">
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

<script lang="ts">
import { AgmTypeArray } from "@augma/shared";
import { defineComponent } from "vue";
import "./index.scss";
export default defineComponent({
  setup() {
    return {
      AgmTypeArray,
    };
  },
});
</script>

<style lang="scss">
.dark-bg {
  background: gray;
  padding: 1rem;
}
</style>
