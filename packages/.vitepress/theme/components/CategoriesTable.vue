<template>
  <div>
    <table class="agm-table">
      <thead>
        <tr>
          <th>类型</th>
          <th>简介</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="category in categories">
          <td>{{ capitalize(category.name) }} {{ category.title }}</td>
          <td>{{ category.description }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts">
import categories from "../../../../meta/categories.json";
import { defineComponent, capitalize } from "vue";
export default defineComponent({
  props: {
    type: {
      type: String,
      default: "components",
    },
  },
  setup(props) {
    return {
      categories: categories[props.type],
      capitalize,
    };
  },
});
</script>
