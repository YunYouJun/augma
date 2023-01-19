<script lang="ts" setup>
const props = withDefaults(defineProps<{
  enable?: boolean
}>(), {
  enable: false,
})

const baiduMapKey = 'YxWdwu2Huhgzy52hmauuqZlQbCOFkpAb'
const style = {}
const inited = ref(false)

/**
 * Create Script
 */
function createScript() {
  const baiduMapScript = document.createElement('script')
  baiduMapScript.setAttribute(
    'src',
    `//api.map.baidu.com/api?type=subway&v=1.0&ak=${baiduMapKey}`,
  )
  document.head.appendChild(baiduMapScript)
}

function initMap() {
  const subwayCityName = '北京'
  const list = BMapSub.SubwayCitiesList
  let subwaycity = null
  for (let i = 0; i < list.length; i++) {
    if (list[i].name === subwayCityName) {
      subwaycity = list[i]
      break
    }
  }
  // 获取北京地铁数据-初始化地铁图
  const subway = new BMapSub.Subway(
    'subway-container',
    subwaycity.citycode,
  )
  subway.setZoom(1)

  inited.value = true
}

watch(() => props.enable, (val) => {
  if (val && !inited.value)
    initMap()
})

onMounted(() => {
  createScript()
})
</script>

<template>
  <div v-show="enable" id="subway-container" :style="style" />
</template>

<style lang="scss">
#subway-container {
  position: absolute;
  top: 4.5rem;
  bottom: 5.5rem;
  background: transparent !important;

  svg {
    text {
      fill: white;
      font-weight: bold;
    }
  }
}
</style>
