<template>
  <agm-indicator
    v-for="(type, i) in TypeMap"
    :key="i"
    :color="type"
    :info="i.toString()"
  />
</template>

<script setup>
import { TypeMap } from "@augma/shared/src";
import AgmIndicator from "./index.vue";
</script>
