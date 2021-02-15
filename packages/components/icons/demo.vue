<template>
  <div class="button-demo">
    <agm-button icon>
      <i-carbon-logo-github style="color: black" />
    </agm-button>
    <agm-button icon type="primary">
      <i-carbon-area />
    </agm-button>
    <agm-button icon type="success">
      <i-carbon-battery-full />
    </agm-button>
    <agm-button icon type="warning">
      <i-carbon-warning />
    </agm-button>
    <agm-button icon type="danger">
      <i-carbon-error />
    </agm-button>
    <agm-button icon type="info">
      <i-carbon-information />
    </agm-button>
  </div>
  <div class="button-demo">
    <agm-button icon outline style="background: black">
      <i-carbon-logo-github style="color: white" />
    </agm-button>
    <agm-button icon type="primary" outline>
      <i-carbon-area />
    </agm-button>
    <agm-button icon type="success" outline>
      <i-carbon-battery-full />
    </agm-button>
    <agm-button icon type="warning" outline>
      <i-carbon-warning />
    </agm-button>
    <agm-button icon type="danger" outline>
      <i-carbon-error />
    </agm-button>
    <agm-button icon type="info" outline>
      <i-carbon-information />
    </agm-button>
  </div>
  <div class="logo-demo text-center">
    <i-carbon-error style="color: var(--agm-danger); font-size: 10rem" />
  </div>
</template>

<script lang="ts">
import AgmButton from "../button/index.vue";
export default {
  components: {
    AgmButton,
  },
};
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
