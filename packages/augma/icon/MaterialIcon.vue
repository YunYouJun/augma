<template>
  <svg class="agm-icon">
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
