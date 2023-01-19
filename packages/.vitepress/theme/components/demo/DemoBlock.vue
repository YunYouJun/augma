<script lang="ts">
import { defineComponent, onErrorCaptured, ref } from 'vue'

export default defineComponent({
  setup() {
    const error = ref(null)

    onErrorCaptured((err) => {
      error.value = err
    })
  },
})
</script>

<template>
  <div class="demo-block hover:shadow-md">
    <div class="demo-content">
      <slot name="demo" />
    </div>
    <div v-if="$slots.description" class="description">
      <slot name="description" class="description" />
    </div>
    <details>
      <summary>Code 代码</summary>
      <div class="-m-2">
        <slot name="code" />
      </div>
    </details>
  </div>
</template>

<style lang="scss">
.demo-block {
  border: solid 1px var(--c-divider);
  border-radius: 3px;
  transition: 0.2s;
  margin-top: 15px;
  margin-bottom: 15px;

  details {
    outline: none;
    border-top: 1px solid var(--c-divider);

    &[open] {
      padding: 1rem 1rem 0.5rem 1rem;
    }
  }

  summary {
    outline: none;
    font-weight: bold;
    padding: 0.8rem 0.8rem 0.8rem 1rem;
    background-color: var(--c-divider-light);
  }

  details[open] summary {
    border-bottom: 1px solid var(--c-divider);
    margin: -1rem -1rem 1rem -1rem;
  }

  .demo-content {
    padding: 1rem;
  }

  .description {
    padding: 1px 1rem;
    border-top: solid 1px var(--c-divider);
    background-color: var(--c-bg);
  }
}
</style>
