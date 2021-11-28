<template>
  <div class="button-demo">
    <agm-button>Button</agm-button>
    <agm-button type="primary">
      Button
    </agm-button>
    <agm-button type="success">
      Button
    </agm-button>
    <agm-button type="warning">
      Button
    </agm-button>
    <agm-button type="danger">
      Button
    </agm-button>
    <agm-button type="info">
      Button
    </agm-button>
  </div>
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
</template>

<script lang="ts" setup>
import AgmIcon from '../icon/index.vue'
import AgmButton from './index.vue'
</script>

<style lang="scss" scoped>
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
