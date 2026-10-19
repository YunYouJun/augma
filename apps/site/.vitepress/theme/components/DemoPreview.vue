<script setup lang="ts">
import { computed, defineAsyncComponent, onUnmounted, shallowRef, watch } from 'vue'
import { useI18n } from '../i18n'

const props = defineProps<{
  name: string
  group?: 'components' | 'compositions'
}>()
const { t } = useI18n()
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
const revision = shallowRef(0)
function reset() {
  ready.value = false
  revision.value++
}
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
    <div class="demo-toolbar">
      <span>{{ t('demo.preview') }}</span>
      <button type="button" :disabled="!demo || !ready" @click="reset">{{ t('demo.reset') }}</button>
    </div>
    <div class="demo-canvas" :aria-busy="!!demo && !ready">
      <component :is="demo" v-if="demo" :key="`${key}-${revision}`" @vue:mounted="ready = true" />
      <p v-else>{{ t('demo.missing') }}</p>
    </div>
    <details class="demo-source">
      <summary>{{ t('demo.source') }}</summary>
      <div class="source-toolbar">
        <span>Vue · TypeScript</span>
        <button type="button" @click="copy">
          {{ copied ? t('copy.copied') : t('demo.copy') }}
        </button>
      </div>
      <span class="agm-sr-only" role="status">{{ copied ? t('demo.copied') : '' }}</span>
      <p v-if="failed" role="status">{{ t('demo.copyFailed') }}</p>
      <pre>
<code>{{ source }}</code>
</pre>
    </details>
  </div>
</template>
