<template>
  <teleport to="body">
    <div v-if="modalOpen" class="modal">
      <div>I'm a modal.</div>
      <button @click="modalOpen = false">Close</button>
    </div>
  </teleport>
</template>

<script>
export default {
  data() {
    return {
      modalOpen: false,
    };
  },
};
</script>
