<script setup lang="ts">
import ComponentStrip from './ComponentStrip.vue'
import DemoPreview from './DemoPreview.vue'
import DevicePreview from './DevicePreview.vue'
import UiIcon from './UiIcon.vue'
</script>

<template>
  <div class="showcase-page">
    <div class="showcase-heading">
      <h1>把界面，带入视界。</h1>
      <p>每个操作都来自真实组件。切换状态、调整参数，再将它们带入你的项目。</p>
      <a href="/components/">查看全部组件</a>
    </div>
    <DevicePreview />
    <ComponentStrip />
    <section class="simulator-entry">
      <div>
        <h2>一副属于你的视界。</h2>
        <p>扫描空间、沿着路线漫游，或为此刻播放一段声音。把组件放进完整的设备体验里。</p>
        <a class="agm-button agm-button--primary" href="/ar/" data-no-router><UiIcon name="scan" />打开设备模拟器</a>
      </div>
      <div class="simulator-features"><span>空间扫描</span><span>路线导航</span><span>声音播放</span><span>通知中心</span><small>无需摄像头，即可开始体验。</small></div>
    </section>
    <section class="composition-gallery">
      <h2>可直接复用的组合</h2>
      <p>展开源码，将完整的控制面板、HUD 或主题示例带入项目。</p>
      <h3>控制面板</h3>
      <DemoPreview name="control-panel" group="compositions" />
      <h3>HUD 状态</h3>
      <DemoPreview name="hud" group="compositions" />
      <h3>主题定制</h3>
      <DemoPreview name="theme" group="compositions" />
    </section>
  </div>
</template>

<style scoped>
.simulator-entry { display: grid; grid-template-columns: 1.5fr 1fr; gap: 48px; padding: 36px; margin: 28px 0 44px; border: 1px solid var(--agm-border); border-left: 3px solid var(--agm-accent); background: var(--agm-panel); }
.simulator-entry h2 { font-size: 27px; font-weight: 500; margin: 0 0 14px; }
.simulator-entry p { font-size: 14px; color: var(--agm-muted); line-height: 1.8; margin: 0 0 24px; }
.simulator-entry svg { width: 20px; height: 20px; }
.simulator-features { display: grid; grid-template-columns: 1fr 1fr; align-content: center; gap: 24px; font-size: 14px; }
.simulator-features span { border-bottom: 1px solid var(--agm-border); padding-bottom: 12px; }
.simulator-features small { grid-column: 1 / -1; color: var(--agm-muted); font-size: 12px; }
@media (max-width: 700px) { .simulator-entry { grid-template-columns: 1fr; gap: 26px; padding: 24px; } }
</style>
