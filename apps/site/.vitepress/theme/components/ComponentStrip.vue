<script setup lang="ts">
import {
  AgmButton,
  AgmHudStatus,
  AgmIconButton,
  AgmPanel,
  AgmSlider,
  AgmSwitch,
  AgmToast,
} from 'augma'
import { shallowRef } from 'vue'

const visible = shallowRef(true)
const opacity = shallowRef(72)
const locked = shallowRef(false)
const notification = shallowRef(false)
</script>

<template>
  <section class="component-strip">
    <h2>从一个按钮，到一整个视界</h2>
    <div class="component-columns">
      <div class="component-column">
        <h3>
          <a href="/components/button">操作</a>
        </h3>
        <p>清晰、直接，即刻响应。</p>
        <div class="button-samples">
          <AgmButton @click="notification = true">主要按钮</AgmButton>
          <AgmButton variant="outline" @click="notification = true">
            次要按钮
          </AgmButton>
          <AgmButton variant="ghost" @click="notification = true">
            轻量操作
          </AgmButton>
          <AgmIconButton label="新增通知" @click="notification = true" />
        </div>
      </div>
      <div class="component-column">
        <h3>
          <a href="/components/switch">控制</a>
        </h3>
        <p>熟悉的交互，在新的场景中。</p>
        <div class="settings-fields">
          <AgmSwitch v-model="visible" label="显示 HUD" />
          <AgmSlider v-model="opacity" label="界面不透明度" :min="20" />
          <AgmSwitch v-model="locked" label="空间锚定" />
        </div>
      </div>
      <div class="component-column">
        <h3>
          <a href="/components/panel">信息</a>
        </h3>
        <p>关键信息，轻盈呈现。</p>
        <div class="mini-hud-space">
          <AgmPanel
            v-if="visible"
            class="mini-hud"
            :style="{ opacity: opacity / 100 }"
          >
            <AgmHudStatus>
              {{ locked ? '已锚定视界' : '界面已就绪' }}
            </AgmHudStatus>
            <p>让信息自然地融入视野。</p>
            <a href="/components/hud-progress">探索 HUD 组件</a>
          </AgmPanel>
          <p v-else class="hidden-hud">HUD 已隐藏，可通过左侧开关恢复。</p>
        </div>
      </div>
    </div>
    <AgmToast
      v-model:open="notification"
      title="操作已响应"
      description="这是由 Augma Toast 组件呈现的反馈。"
    />
  </section>
</template>
