<template>
  <div class="demo-block">
    <div class="demo-content">
      <slot name="demo"></slot>
    </div>
    <div v-if="$slots.description" class="description">
      <slot name="description" class="description"></slot>
    </div>
    <details>
      <summary>Code 代码</summary>
      <slot name="code"></slot>
    </details>
  </div>
</template>

<script setup lang="ts">
import { onErrorCaptured, ref } from "vue";

const error = ref(null);

onErrorCaptured((err) => {
  error.value = err;
});
</script>

<style lang="scss">
.demo-block {
  --demo-border-color: #eee;

  border: solid 1px #ebebeb;
  border-radius: 3px;
  transition: 0.2s;
  margin-top: 15px;
  margin-bottom: 15px;

  details {
    outline: none;
    border-top: 1px solid var(--demo-border-color);

    &[open] {
      padding: 1rem 1rem 0 1rem;
    }
  }

  summary {
    outline: none;
    font-weight: bold;
    padding: 0.8rem 0.8rem 0.8rem 1rem;
    background-color: #fafafa;
  }

  details[open] summary {
    border-bottom: 1px solid var(--demo-border-color);
    margin: -1rem -1rem 1rem -1rem;
  }

  &:hover {
    box-shadow: 0 0 8px 0 rgba(232, 237, 250, 0.6),
      0 2px 4px 0 rgba(232, 237, 250, 0.5);
  }

  .demo-content {
    padding: 1rem;
  }

  .description {
    padding: 1px 1rem;
    border-top: solid 1px var(--demo-border-color);
    background-color: #fcfcfc;
  }
}
</style>
