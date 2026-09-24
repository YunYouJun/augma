<script setup lang="ts">
import { AgmButton, AgmDialog, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

defineProps<{ storageAvailable: boolean, reducedMotion: boolean }>()
const emit = defineEmits<{ reset: [] }>()
const opacity = defineModel<number>('opacity', { required: true })
const dark = defineModel<boolean>('dark', { required: true })
const focus = defineModel<boolean>('focus', { required: true })
const mirror = defineModel<boolean>('mirror', { required: true })
const depthMotion = defineModel<boolean>('depthMotion', { required: true })
const curvedHud = defineModel<boolean>('curvedHud', { required: true })
const resetOpen = shallowRef(false)
function focusResetTrigger(event: MouseEvent) {
  // Safari does not focus a button on pointer click; the dialog needs its trigger focused.
  if (event.currentTarget instanceof HTMLElement)
    event.currentTarget.focus({ preventScroll: true })
}
function reset() {
  emit('reset')
  resetOpen.value = false
}
</script>

<template>
  <div class="feature-body">
    <div class="display-fields">
      <AgmSlider v-model="opacity" label="面板不透明度" :min="60" />
      <AgmSwitch v-model="dark" label="深色视界" />
      <AgmSwitch v-model="focus" label="专注模式" />
      <AgmSwitch v-model="mirror" label="镜像画面" />
    </div>
    <fieldset class="visual-effects">
      <legend>视界效果</legend>
      <AgmSwitch v-model="depthMotion" label="景深动画" />
      <p>移动鼠标体验前后景视差，浮窗展开时轻柔浮现。</p>
      <AgmSwitch v-model="curvedHud" label="弧线视界" />
      <p>将上下白线和底部图标排列为浅弧形。</p>
      <p v-if="reducedMotion" class="motion-note" role="status">系统已开启减少动态效果，景深动画暂停；弧线外观仍可使用。</p>
    </fieldset>
    <p class="settings-hint">拖动应用面板标题可调整位置；聚焦标题后也可用方向键移动。专注模式收起场景锚点，保留当前应用。镜像仅作用于摄像头画面。</p>
    <p class="settings-storage" role="status">{{ storageAvailable ? '显示与音量设置已自动保存在此浏览器。' : '当前浏览器无法保存设置，本次体验仍可正常使用。' }}</p>
    <AgmDialog v-model:open="resetOpen" title="恢复默认设置" description="恢复面板位置、主题、声音、HUD 和视界效果的初始设置。当前模拟场景不变。">
      <template #trigger><AgmButton class="full-button" variant="outline" @click="focusResetTrigger">恢复默认设置</AgmButton></template>
      <template #footer><AgmButton variant="ghost" @click="resetOpen = false">取消</AgmButton><AgmButton @click="reset">确认恢复</AgmButton></template>
    </AgmDialog>
  </div>
</template>

<style scoped>
.display-fields { display: grid; gap: 25px; margin: 26px 0; }
.visual-effects { display: grid; gap: 12px; margin: 0 0 24px; padding: 18px 0 0; border: 0; border-top: 1px solid var(--agm-border); }
.visual-effects legend { padding: 0 12px 0 0; font-size: 12px; color: white; }
.visual-effects p { margin: -4px 0 6px; font-size: 11px; color: var(--agm-muted); line-height: 1.7; }
.visual-effects .motion-note { margin: 0; color: #c0e497; }
.settings-hint, .settings-storage { font-size: 12px; color: var(--agm-muted); line-height: 1.8; }
.settings-storage { border-top: 1px solid var(--agm-border); padding-top: 20px; margin: 24px 0 20px; }
</style>
