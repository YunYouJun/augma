<template>
  <div class="agm-menu">
    <slot name="activator"></slot>
    <transition name="slide-fade">
      <div v-if="modelValue" class="agm-menu-items">
        <slot></slot>
      </div>
    </transition>
  </div>
</template>

<script>
export default {
  name: "AgmMenu",
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
  },
};
</script>

<style lang="scss">
.slide-fade-enter-active {
  transition: all 0.4s ease;
}
.slide-fade-leave-active {
  transition: all 0.4s ease;
}
.slide-fade-enter-from,
.slide-fade-leave-to {
  transform: translateY(-10px);
  opacity: 0;
}

.agm-menu-items {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 10px;
}
</style>
