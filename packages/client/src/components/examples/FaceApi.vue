<script lang="ts" setup>
import * as faceapi from 'face-api.js'
import { useAppStore } from '~/stores/app'
import { useCameraStore } from '~/stores/camera'

const props = withDefaults(defineProps<{
  enable?: boolean
  customClass?: string[]
}>(), {
  enable: false,
  customClass: () => [],
})

// import * as faceapi from "@vladmandic/face-api";
const app = useAppStore()

const name = ref('YunYouJun')
const score = ref(0)

const videoEl = ref()
const overlay = ref()

const minConfidence = ref(0.5)
const withBoxes = ref(false)

const indicatorStyle = computed(() => {
  return {
    position: 'absolute',
    top: '5rem',
    transform: 'translateX(-50%)',
    transition: 'all 0.2s',
  }
})

watch(() => props.enable, async () => {
  if (props.enable) {
    app.loading = true
    await loadModel()
    app.loading = false
    onPlay()
  }
})

const camera = useCameraStore()

onMounted(() => {
  videoEl.value = camera.videoEl

  overlay.value.width = document.body.clientWidth
  overlay.value.height = document.body.clientHeight
})

async function loadModel() {
  const faceApiWeightsUri = '/models/weights'
  // const faceApiWeightsUri =
  //   "https://raw.githubusercontent.com/justadudewhohacks/face-api.js/master/weights";
  await faceapi.nets.tinyFaceDetector.loadFromUri(faceApiWeightsUri)
  // await faceapi.nets.ageGenderNet.loadFromUri(faceApiWeightsUri);
}

async function onPlay() {
  if (!props.enable)
    return

  const videoEl = this.videoEl

  if (videoEl.paused || videoEl.ended)
    return setTimeout(() => onPlay())

  // tiny_face_detector options
  const inputSize = 512
  const scoreThreshold = 0.5
  const options = new faceapi.TinyFaceDetectorOptions({
    inputSize,
    scoreThreshold,
  })

  const result = await faceapi.detectSingleFace(videoEl, options)

  if (result)
    this.drawDetectionsResults(result)

  setTimeout(() => {
    onPlay()
  }, 100)
}

function drawDetectionsResults(result) {
  const videoEl = this.videoEl
  const canvas = this.overlay
  const dims = faceapi.matchDimensions(canvas, videoEl, true)

  const resizedResult = faceapi.resizeResults(result, dims)

  score.value = resizedResult.score.toFixed(7).toString()
  setIndicatorByBox(resizedResult.box)
  if (this.withBoxes)
    faceapi.draw.drawDetections(canvas, resizedResult)

  // const { age, gender, genderProbability } = resizedResult;

  // interpolate gender predictions over last 30 frames
  // to make the displayed age more stable
  // const interpolatedAge = interpolateAgePredictions(age);
  // new faceapi.draw.DrawTextField(
  //   [
  //     `${faceapi.utils.round(interpolatedAge, 0)} years`,
  //     `${gender} (${faceapi.utils.round(genderProbability)})`,
  //   ],
  //   result.detection.box.bottomLeft
  // ).draw(canvas);
}

function setIndicatorByBox(box) {
  const ratio = camera.ratio
  this.indicatorStyle.top = `${box.top - 180}px`
  this.indicatorStyle.left = `${(box.left + box.width / 2) * ratio}px`
}
</script>

<template>
  <canvas v-show="enable" id="overlay" ref="overlay" />
  <agm-indicator
    v-show="enable"
    :class="customClass"
    :name="name"
    :info="score"
    :style="indicatorStyle"
  />
</template>

<style lang="scss">
#overlay {
  position: absolute;
  width: 100vw;
  height: 100vh;
  object-fit: cover;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;

  pointer-events: none;
}
</style>
