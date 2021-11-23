<template>
  <agm-button type="primary" @click="notify">
    弹出消息通知
  </agm-button>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import AgmButton from '../button/index.vue'
import pkg from '../../../package.json'

export default defineComponent({
  components: {
    AgmButton,
  },
  methods: {
    notify() {
      this.$notify({
        title: 'GitHub',
        icon: 'mdi:github',
        color: 'black',
        message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
        duration: 0,
        showClose: true,
      })
    },
  },
})
</script>
