<script lang="ts" setup>
const props = defineProps<{ opacity: number }>()

const loadingContainer = ref()

const styles = computed(() => ({
  opacity: props.opacity,
}))

// app.loading

onMounted(() => {
  // const loader = $loading.show({
  //   container: loadingContainer.value,
  // })
  // todo
  // add custom components/loading.scss

  // setTimeout(() => {
  //   loader && loader.hide()
  // }, 100)
})
</script>

<template>
  <div id="augma-ui" class="augma-ui" :style="styles">
    <div id="agm-loading-container" ref="loadingContainer" />

    <AgmSystemBar />
    <AgmWindow />
    <!-- <TfjsYolo :enable="app.yolo" /> -->
    <div class="augma-bottom-menu-container">
      <BottomMenu />
    </div>
  </div>
</template>

<style lang="scss">
.augma-ui {
  position: fixed;
  text-align: center;
  left: 0;
  top: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(255, 255, 255, 0.1);
}

.augma-bottom-menu-container {
  position: fixed;
  left: 0;
  bottom: 0;

  width: 100%;
  margin: 0 auto;
}
</style>
