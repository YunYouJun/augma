<script setup lang="ts">
import { computed, defineAsyncComponent, onUnmounted, shallowRef, watch } from 'vue'

const props = defineProps<{
  name: string
  group?: 'components' | 'compositions'
}>()
const examples = import.meta.glob('../../../../../examples/**/*.vue')
const sources = import.meta.glob('../../../../../examples/**/*.vue', {
  query: '?raw',
  import: 'default',
  eager: true,
})
const key = computed(
  () =>
    `../../../../../examples/${props.group ?? 'components'}/${props.name}.vue`,
)
const demo = computed(() =>
  examples[key.value]
    ? defineAsyncComponent(
        examples[key.value] as () => Promise<{
          default: import('vue').Component
        }>,
      )
    : undefined,
)
const source = computed(() => String(sources[key.value] ?? ''))
const ready = shallowRef(false)
watch(key, () => {
  ready.value = false
})
const copied = shallowRef(false)
const failed = shallowRef(false)
let timer: ReturnType<typeof setTimeout> | undefined
async function copy() {
  try {
    await navigator.clipboard.writeText(source.value)
    copied.value = true
    failed.value = false
    clearTimeout(timer)
    timer = setTimeout(() => {
      copied.value = false
    }, 2000)
  }
  catch {
    failed.value = true
  }
}
onUnmounted(() => clearTimeout(timer))
</script>

<template>
  <div class="demo-block">
    <div class="demo-canvas" :aria-busy="!ready">
      <component :is="demo" v-if="demo" @vue:mounted="ready = true" />
      <p v-else>未找到示例。</p>
    </div>
    <details class="demo-source">
      <summary>查看 Vue 源码</summary>
      <div class="source-toolbar">
        <span>Vue · TypeScript</span>
        <button type="button" @click="copy">
          {{ copied ? '已复制' : '复制代码' }}
        </button>
      </div>
      <p v-if="failed" role="status">复制失败，请选中下方源码复制。</p>
      <pre>
<code>{{ source }}</code>
</pre>
    </details>
  </div>
</template>
