<template>
  <hr class="agm-hr" />
</template>

<script>
export default {
  name: "AgmHr",
};
</script>

<style lang="scss">
@import "../../theme/variables/index.scss";
.agm-hr {
  height: $agm-line-width;
  border: none;
  background: white;
  margin: 0.5rem 3.5rem;
}
</style>
