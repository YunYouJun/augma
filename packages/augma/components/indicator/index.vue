<template>
  <div class="agm-indicator">
    <h2 class="agm-indicator__title">
      {{ name }}
    </h2>
    <div class="agm-indicator__info">
      {{ info }}
    </div>
    <div class="agm-indicator__cursor"></div>
  </div>
</template>

<script>
export default {
  name: "AgmIndicator",
  props: {
    name: {
      type: String,
      default: "Asuna",
    },
    info: {
      type: String,
      default: "318",
    },
  },
};
</script>

<style lang="scss">
.agm-indicator {
  position: relative;
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  filter: drop-shadow(0 0 2px var(--agm-warning));

  &__title {
    color: white;
  }

  &__info {
    padding: 0.3rem 1rem;
    color: #666666;
    line-height: 1;
    background: white;
    min-width: 5rem;
    font-size: 1.1rem;
    font-weight: bold;
  }

  &__cursor {
    position: absolute;
    margin: 0 auto;
    top: 4.5rem;
    left: 0;
    right: 0;
    width: 0;
    height: 0;
    border: 1.2rem solid white;
    border-color: white transparent transparent transparent;
  }
}
</style>
