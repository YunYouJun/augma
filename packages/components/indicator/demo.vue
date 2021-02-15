<template>
  <agm-indicator
    v-for="(type, i) in colorTypes"
    :key="i"
    :color="type"
    :info="i.toString()"
  />
</template>

<script setup>
import { colorTypes } from "@augma/shared/src";
import AgmIndicator from "./index.vue";
</script>
