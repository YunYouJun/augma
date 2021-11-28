import { acceptHMRUpdate, defineStore } from 'pinia'

export const useAppStore = defineStore('app', () => {
  /**
   * 加载动画
   */
  const loading = ref(false)
  const subwayMap = ref(false)
  const weather = ref(false)
  const yolo = ref(false)
  const faceDetection = ref(false)
  const browser = ref(false)

  const toggleSubwayMap = useToggle(subwayMap)
  const toggleWeather = useToggle(weather)
  const toggleYolo = useToggle(yolo)
  const toggleFaceDetection = useToggle(faceDetection)
  const toggleBrowser = useToggle(browser)

  return {
    loading,
    subwayMap,
    weather,
    yolo,
    faceDetection,
    browser,

    toggleWeather,
    toggleSubwayMap,
    toggleYolo,
    toggleFaceDetection,
    toggleBrowser,
  }
})

if (import.meta.hot)
  import.meta.hot.accept(acceptHMRUpdate(useAppStore, import.meta.hot))
