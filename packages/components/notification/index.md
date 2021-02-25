---
title: 通知
category: utilities
props:
  - name: title
    description: 标题
    type: string
  - name: color
    description: 颜色
    type: string
    acceptedValues: CSS3 Color
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
