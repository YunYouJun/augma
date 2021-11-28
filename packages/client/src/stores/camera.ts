import { acceptHMRUpdate, defineStore } from 'pinia'

export const useCameraStore = defineStore('camera', () => {
  const videoEl = ref()
  const settings = ref()
  const display = ref(false)
  const flipScreen = ref(false)
  const front = ref(false)
  const ratio = ref(1)

  const toggleDisplay = useToggle(display)
  const toggleFlipScreen = useToggle(flipScreen)
  const toggleFront = useToggle(front)

  return {
    videoEl,
    settings,
    display,
    flipScreen,
    front,
    ratio,

    toggleDisplay,
    toggleFlipScreen,
    toggleFront,
  }
})

if (import.meta.hot)
  import.meta.hot.accept(acceptHMRUpdate(useCameraStore, import.meta.hot))
