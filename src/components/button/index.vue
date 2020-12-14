<template>
  <button :class="classes" :style="styles">
    <slot></slot>
  </button>
</template>

<script lang="ts">
export default {
  props: {
    color: String,
    icon: Boolean,
  },
  computed: {
    classes() {
      return {
        "agm-button": true,
        "agm-button--icon": this.icon,
      };
    },
    styles() {
      return {
        color: this.color,
      };
    },
  },
};
</script>

<style lang="scss">
.agm {
  &-button {
    display: flex;
    align-items: center;
    justify-content: center;

    width: 2.6rem;
    height: 2.6rem;
    background: white;

    border: none;
    outline: none;

    box-shadow: 0 0 5px rgba(0, 0, 0, 0.2);
    font-size: 1.3rem;

    &:focus {
      outline: none;
    }

    &:active {
      box-shadow: 0 0 10px rgba(31, 82, 144, 0.5);
    }

    &--icon {
      border-radius: 50%;
    }
  }
}
</style>
