---
category: misc
---

# 色彩

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

.text-black {
  color: black;
}

.text-capitalize {
  text-transform: capitalize;
}

.text-uppercase {
  text-transform: uppercase;
}
</style>

<script>
export default {
  data() {
    return {
      auxiliaryColors: [
        {
          name: "brand",
          value: "",
        },
        {
          name: "success",
          value: ""
        },
        {
          name: "warning",
          value: ""
        },
        {
          name: "error",
          value: ""
        },
        {
          name: "info",
          value: ""
        },
        {
          name: "tooltip",
          value: ""
        }
      ]
    }
  },
  mounted() {
    this.auxiliaryColors.forEach((color)=> {
      color.value = getComputedStyle(document.documentElement).getPropertyValue(`--agm-${color.name}`);
    })
  }
}
</script>

Augma 是面向 AR 交互的 UI 框架，应避免过于复杂的色彩，并能够与复杂的背景区分开。

为了不遮挡真实视野，UI 界面通常带有些许透明，可通过全局透明度进行控制。

## 主色

通常以白色为主。

<div class="demo-color-box text-black">
White <div class="value">#FFFFFF</div>
</div>

## 辅助色

除了主色调外，需要不同的颜色以区分不同的操作状态。

<div class="demo-color-box-group">
  <div
    v-for="color in auxiliaryColors"
    class="demo-color-box demo-color-box-other demo-color-box-lite"
    :style="{ background: color.value }"
  >
    <div class="name text-capitalize">{{color.name}}</div>
    <div class="value text-uppercase">{{color.value}}</div>
  </div>
</div>