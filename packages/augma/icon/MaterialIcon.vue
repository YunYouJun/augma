<template>
  <svg class="agm-icon" viewbox="0 0 24 24">
    <path :d="icon"></path>
  </svg>
</template>

<script>
export default {
  props: {
    icon: String,
  },
};
</script>
