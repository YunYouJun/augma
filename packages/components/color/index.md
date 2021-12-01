---
title: 色彩
category: misc
---

## 说明

<style lang="scss">
.demo-color-box {
  border-radius: 4px;
  padding: 20px;
  height: 5rem;
  box-sizing: border-box;
  color: #fff;
  font-size: 1rem;
  margin: 5px;
  box-shadow: 0 0 10px rgba(0,0,0,0.1);
}

.demo-color-box-group {
  .demo-color-box {
    border-radius: 0;
    margin: 0 5px;
  }
  .demo-color-box:first-child {
    border-radius: 4px 4px 0 0;
  }
  .demo-color-box:last-child {
    border-radius: 0 0 4px 4px;
  }
}
</style>

Augma 是面向 AR 交互的 UI 框架，应避免过于复杂的色彩，并能够与复杂的背景区分开。

为了不遮挡真实视野，UI 界面通常带有些许透明，可通过全局透明度进行控制。

## 主色

通常以白色为主。

<div class="demo-color-box text-black">
White <div class="value">#FFFFFF</div>
</div>

## 辅助色

除了主色调外，需要不同的颜色以区分不同的操作状态。

<auxiliary />

## 阴影色

我们在 Augma 中发现不同元素的 shadow 色是统一的，但是在不同场景下则会有不同的阴影色彩。

这对于增加元素与场景的对比度应该会很有用。

譬如我们可以这样设置，来改变全局的阴影色彩。

```css
<style>
.agm-shadow {
  --un-shadow-color: 255,0,0;
}
</style>
```

<style>
.agm-shadow {
  --un-shadow-color: 255,0,0;
}
</style>
