<template>
  <div v-show="enable" id="subway-container" :style="style"></div>
</template>

<script>
export default {
  props: {
    enable: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      baiduMapKey: 'YxWdwu2Huhgzy52hmauuqZlQbCOFkpAb',
      style: {},
      inited: false,
    }
  },
  watch: {
    enable(val) {
      if (val && !this.inited) {
        setTimeout(() => {
          this.initMap()
        }, 2000)
      }
    },
  },
  mounted() {
    this.createScript()
  },
  methods: {
    createScript() {
      const baiduMapScript = document.createElement('script')
      baiduMapScript.setAttribute(
        'src',
        `//api.map.baidu.com/api?type=subway&v=1.0&ak=${this.baiduMapKey}`,
      )
      document.head.appendChild(baiduMapScript)
    },
    initMap() {
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

      this.inited = true
    },
  },
}
</script>

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
