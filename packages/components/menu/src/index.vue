<template>
  <div class="agm-menu">
    <div class="agm-menu--activator" @click="handleClick">
      <slot name="activator" />
    </div>

    <transition name="slide-fade">
      <div v-if="modelValue" class="agm-menu-items">
        <slot />
      </div>
    </transition>
  </div>
</template>

<script lang="ts" setup>
import './index.scss'
import { UPDATE_MODEL_EVENT } from 'augma'

const props = withDefaults(defineProps<{
  modelValue: boolean
}>(), {
  modelValue: false,
})

const emit = defineEmits([UPDATE_MODEL_EVENT])

function handleClick() {
  emit(UPDATE_MODEL_EVENT, !props.modelValue)
}
</script>
