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
  - name: message
    type: string
    description: 消息内容
  - name: showClose
    type: boolean
    description: 是否显示关闭按钮
    default: "false"
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
