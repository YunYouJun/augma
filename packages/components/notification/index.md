---
title: 通知
category: utilities
description: 弹出消息通知
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

::: info

起初我参考 Element Plus 实现了 Notification，但我发现这也许并不是本组件库的目的。
重复造轮子总是没有必要的，而 Augma 虽然需要这个功能，但是更主要的是想要其能适配对应的 UI。

:::

```js
this.$notify({
  title: "GitHub",
  icon: mdiGithub,
  color: "black",
  message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
  duration: 0,
});
```
