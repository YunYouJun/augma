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
    default: false
---

::: info

起初我参考 Element Plus 实现了 Notification，但后来我觉得这也许并不是本组件库的目的。
重复造轮子总是没有必要的。

尽管 Augma 虽然需要这个功能，但是更主要的目的是想要一个适配对应 UI 的 notification。

因此完全可以使用现有的 notification 组件进行 UI 层面上的改造和 API 封装简化。

Augma 由 Vue3 构建，因此我打算基于 [vue-toastification](https://github.com/Maronato/vue-toastification) 实现。

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
