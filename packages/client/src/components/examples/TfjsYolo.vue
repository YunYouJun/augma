<template>
  <div v-if="enable" id="rects">
    <div
      v-for="(box, i) in boxes"
      :key="i"
      class="agm-rect"
      :style="{
        top: `${box.top}px`,
        left: `${box.left * $store.state.camera.ratio}px`,
        width: `${box.width}px`,
        height: `${box.height}px`,
        boxShadow: `0 0 5px rgba(0,0,0,0.3)`,
      }"
    >
      <agm-indicator
        :name="box.class"
        :info="box.score.toFixed(2)"
        :style="{
          transform: 'translateY(-150%)',
        }"
      />
    </div>
  </div>
</template>

<script lang="ts">
import yolo from 'tfjs-yolo'
import { defineComponent } from 'vue'
export default defineComponent({
  props: {
    enable: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      yolo: null,
      colors: {},
      boxes: [],
    }
  },
  watch: {
    async enable(val) {
      if (val) {
        this.$store.commit('app/setLoading', true)
        await this.loadModel()
        this.$store.commit('app/setLoading', false)
        this.run()
      }
    },
  },
  methods: {
    async loadModel() {
      const isLocal = true

      if (isLocal)
        this.yolo = await yolo.v3tiny('/v3tiny/model.json')
      else
        this.yolo = await yolo.v3()
    },
    async run() {
      await this.predict()
      setTimeout(() => {
        this.run()
      }, 500)
    },
    async predict(threshold) {
      const videoEl = this.$store.state.camera.videoEl
      const boxes = await this.yolo.predict(videoEl, {
        scoreThreshold: threshold,
      })
      this.boxes = boxes
      this.drawBoxes(boxes)
    },
    drawBoxes(boxes) {
      const colors = this.colors
      boxes.forEach((box) => {
        if (!(box.class in colors)) {
          colors[box.class]
            = `#${Math.floor(Math.random() * 16777215).toString(16)}`
        }
      })
    },
  },
})
</script>

<style lang="scss">
#rects {
  position: relative;
}

.agm-rect {
  position: absolute;
  border: 2px solid white;
  border-radius: 4px;
  transition: all 0.2s;

  display: flex;
  justify-content: center;
  align-items: flex-start;
}
</style>
