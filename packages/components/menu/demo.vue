<script lang="ts" setup>
import { ref } from 'vue'
import { AgmButton, AgmIcon, AgmMenu } from 'augma'

const open = ref(false)
</script>

<template>
  <AgmMenu v-model="open">
    <template #activator>
      <AgmButton icon>
        <AgmIcon v-if="open" name="i-mdi-dots-vertical" />
        <AgmIcon v-else name="i-mdi-dots-horizontal" />
      </AgmButton>
    </template>
    <AgmButton icon type="primary" color="blue" plain>
      <AgmIcon name="i-mdi-fullscreen" />
    </AgmButton>
    <AgmButton icon type="success" color="green" plain>
      <AgmIcon name="i-mdi-check" />
    </AgmButton>
  </AgmMenu>
</template>
