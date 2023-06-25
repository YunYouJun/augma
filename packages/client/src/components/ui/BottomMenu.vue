<script lang="ts" setup>
import pkg from '../../../package.json'
import { useCameraStore } from '~/stores/camera'
import { useAppStore } from '~/stores/app'

const app = useAppStore()
const camera = useCameraStore()

const mode = ref('use')
const browser = ref(false)

function screenshot() {
  const video = camera.videoEl
  if (!video) {
    console.error('No camera is opened.')
    return
  }
  const canvas = document.createElement('canvas')
  // canvas.width = video.clientWidth;
  // canvas.height = video.clientHeight;
  const settings = camera.settings
  canvas.width = settings.width
  canvas.height = settings.height
  const ctx = canvas.getContext('2d')
  ctx.drawImage(video, 0, 0)

  const dataUrl = canvas.toDataURL()
  const link = document.createElement('a')
  link.href = dataUrl
  link.download = new Date().toString()
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}

const menuItems = [
  { color: '#8dd3d6', icon: 'i-mdi-flip-horizontal', do: camera.toggleFlipScreen },
  {
    color: 'var(--agm-color-warning)',
    icon: 'i-mdi-weather-cloudy',
    do: app.toggleWeather,
  },
  {
    color: '#4dade0',
    icon: 'i-mdi-eye',
    do: camera.toggleDisplay,
  },
  {
    color: 'var(--agm-color-info)',
    icon: 'i-mdi-face',
    do: app.toggleFaceDetection,
  },
  {
    color: 'var(--agm-color-tooltip)',
    icon: 'i-mdi-cube-scan',
    do: app.toggleYolo,
  },
  {
    color: '#4dade0',
    icon: 'i-mdi-camera',
    do: screenshot,
  },
  {
    color: '#dd9d5e',
    icon: 'i-mdi-map',
    do: app.toggleSubwayMap,
  },

  {
    icon: 'i-mdi-github',
    do: openGithubNotification,
  },
  {
    color: '#4dade0',
    icon: 'i-mdi-earth',
    do: app.toggleBrowser,
  },
]

onMounted(() => {
  if (mode.value === 'demo')
    openGithubNotification()
})

function openGithubNotification() {
  this.$notify({
    title: 'GitHub',
    icon: 'mdi:github',
    color: 'black',
    message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
    // showClose: true,
  })
}
</script>

<template>
  <agm-bottom-menu :menu-items="menuItems" />
</template>
