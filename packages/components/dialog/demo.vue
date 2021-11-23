<template>
  <agm-button type="primary" @click="dialogVisible = !dialogVisible">
    点击打开 Dialog
  </agm-button>
  <agm-dialog v-model="dialogVisible">
    <template #header>
      标题
    </template>
    这是一段信息
  </agm-dialog>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import AgmButton from '../button/index.vue'
import AgmDialog from './index.vue'

export default defineComponent({
  components: {
    AgmButton,
    AgmDialog,
  },
  data() {
    return {
      dialogVisible: false,
    }
  },
})
</script>
