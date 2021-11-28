<template>
  <div class="button-demo">
    <agm-button icon>
      <agm-icon icon="mdi:github" color="black" />
    </agm-button>
    <agm-button icon type="primary">
      <agm-icon icon="mdi:vector-square" />
    </agm-button>
    <agm-button icon type="success">
      <agm-icon icon="mdi:check" />
    </agm-button>
    <agm-button icon type="warning">
      <agm-icon icon="mdi:warning" />
    </agm-button>
    <agm-button icon type="danger">
      <agm-icon icon="mdi:error" />
    </agm-button>
    <agm-button icon type="info">
      <agm-icon icon="mdi:information-variant" />
    </agm-button>
  </div>
  <div class="button-demo">
    <agm-button icon outline style="background: black">
      <agm-icon icon="mdi:github" color="white" />
    </agm-button>
    <agm-button icon type="primary" outline>
      <agm-icon icon="mdi:vector-square" />
    </agm-button>
    <agm-button icon type="success" outline>
      <agm-icon icon="mdi:check" />
    </agm-button>
    <agm-button icon type="warning" outline>
      <agm-icon icon="mdi:warning" />
    </agm-button>
    <agm-button icon type="danger" outline>
      <agm-icon icon="mdi:error" />
    </agm-button>
    <agm-button icon type="info" outline>
      <agm-icon icon="mdi:information-variant" />
    </agm-button>
  </div>
  <div class="logo-demo text-center">
    <agm-icon
      icon="mdi:do-not-disturb-off"
      color="var(--agm-color-danger)"
      size="10rem"
    />
  </div>
</template>

<script lang="ts">
import AgmButton from '../button/index.vue'
import AgmIcon from './index.vue'
export default {
  components: {
    AgmButton,
    AgmIcon,
  },
}
</script>

<style lang="scss" scoped>
.text-center {
  text-align: center;
}

.button-demo {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;

  & > * {
    margin: 0 1rem 1rem 0;
  }
}
</style>
