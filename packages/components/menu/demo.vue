<template>
  <agm-menu v-model="open">
    <template #activator>
      <agm-button icon>
        <agm-icon v-if="open" icon="mdi:dots-vertical" />
        <agm-icon v-else icon="mdi:dots-horizontal" />
      </agm-button>
    </template>
    <agm-button icon type="primary" outline>
      <agm-icon icon="mdi:fullscreen" />
    </agm-button>
    <agm-button icon type="success" outline>
      <agm-icon icon="mdi:check" />
    </agm-button>
  </agm-menu>
</template>

<script lang="ts" setup>
import { ref } from 'vue'
import AgmButton from '../button/index.vue'
import AgmIcon from '../icon/index.vue'
import AgmMenu from './index.vue'

const open = ref(false)
</script>
