<template>
  <agm-menu v-model="open">
    <template #activator>
      <agm-button icon>
        <agm-icon v-if="open" name="i-mdi-dots-vertical" />
        <agm-icon v-else name="i-mdi-dots-horizontal" />
      </agm-button>
    </template>
    <agm-button icon type="primary" color="blue" plain>
      <agm-icon name="i-mdi-fullscreen" />
    </agm-button>
    <agm-button icon type="success" color="green" plain>
      <agm-icon name="i-mdi-check" />
    </agm-button>
  </agm-menu>
</template>

<script lang="ts" setup>
import { ref } from 'vue'
import { AgmButton, AgmIcon, AgmMenu } from 'augma'

const open = ref(false)
</script>
