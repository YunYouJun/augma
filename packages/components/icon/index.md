---
title: 图标
category: misc
---

推荐使用 [Material Design Icons](https://materialdesignicons.com/)

```sh
yarn add -D @mdi/js
```

```vue
<template>
  <agm-icon :icon="icon"></agm-icon>
</template>

<script>
import { mdiMicrophone } from "@mdi/js";

export default {
  data() {
    return {
      icon: mdiMicrophone,
    };
  },
};
</script>
```
