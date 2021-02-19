<template>
  <div class="demo-input">
    <agm-input v-model="input" placeholder="请输入内容"></agm-input>
    <agm-input
      v-model="input"
      :disabled="true"
      placeholder="禁用状态"
    ></agm-input>
    <agm-input v-model="input" placeholder="可清空" clearable>
      <!-- <template #suffix> s </template> -->
    </agm-input>
    <agm-input v-model="input" placeholder="密码框" show-password></agm-input>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref } from "vue";

import AgmInput from "./index.vue";
export default defineComponent({
  components: {
    AgmInput,
  },
  setup() {
    return {
      input: ref(""),
    };
  },
});
</script>

<style lang="scss">
.demo-input {
  .agm-input {
    margin: 0.5rem 0;
  }
}
</style>
