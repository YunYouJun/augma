<script lang="ts" setup>
import { AgmButton, useAgmToast } from 'augma'
import pkg from '../../../package.json'

const toast = useAgmToast()

function sendMessage() {
  // notify({
  //   title: 'GitHub',
  //   icon: 'mdi:github',
  //   color: 'black',
  //   message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
  //   duration: 0,
  //   showClose: true,
  // })
  // notify.success('asd')
  toast(`<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`, {
    icon: {
      iconClass: 'i-mdi-github',
    },
    timeout: 3000,
  })
}
</script>

<template>
  <AgmButton type="primary" @click="sendMessage">
    弹出消息通知
  </AgmButton>
</template>
