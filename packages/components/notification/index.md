---
title: 通知
category: utilities
---

弹出消息通知

```js
this.$notify({
  title: "GitHub",
  icon: mdiGithub,
  color: "black",
  message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
  duration: 0,
});
```

| 参数  | 说明 | 类型   | 可选值 | 默认值 |
| ----- | ---- | ------ | ------ | ------ |
| title | 标题 | string | -      | -      |
| color | 颜色 | string |        |        |
