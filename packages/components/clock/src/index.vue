<template>
  <span class="agm-clock" :class="classes">{{ now }}</span>
</template>

<script lang="ts" setup>
import './index.scss'
import type { AgmColorType } from '@augma/shared'
import { computed, onMounted } from 'vue'

interface DisplayTime {
  hour: number
  minute: number
}

const props = withDefaults(defineProps<{
  color?: AgmColorType
  addZero?: boolean
}>(), {
  color: '',
  addZero: true,
})

let { hour, minute }: DisplayTime = getTime()

function getTime() {
  const date = new Date()
  return { hour: date.getHours(), minute: date.getMinutes() }
}

// const styles = computed(() => {
//   return {
//     color: getAgmColorByType(props.color),
//   }
// })

const classes = computed(() => {
  return [props.color && `text-${props.color}-500`]
})

const now = computed(() => {
  if (props.addZero) {
    const addZeroForH: boolean = hour.toString().length === 1
    const curHour = (addZeroForH ? '0' : '') + hour
    const addZeroForM = minute.toString().length === 1
    const curMinute = (addZeroForM ? '0' : '') + minute
    return `${curHour}:${curMinute}`
  }
  else {
    return `${hour}:${minute}`
  }
})

onMounted(() => {
  setInterval(() => {
    const time = getTime()
    hour = time.hour
    minute = time.minute
  }, 1000)
})
</script>
