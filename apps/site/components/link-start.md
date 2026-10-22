# Link Start 链接启动

光之隧道过场：跳转前铺满屏幕，再在到达的页面上淡出。

约 240 道光线从屏幕中央涌出，中央浮现 LINK START，一秒后以闪光盖住画面，并停在目标页面的背景色上；页面切换完成后，遮罩淡出。它是一个与框架无关的函数，而不是组件：遮罩挂在 `document.body` 上，路由切换时不会随组件卸载。

## 基础用法

<DemoPreview name="link-start" />

## 配合路由

把跳转写进回调。`linkStart` 在屏幕被盖住后执行它，等新页面就位再淡出。传入 `waitFor` 时，会等到旧页面中匹配该选择器的元素离开后才淡出，避免露出旧页面。

```ts
import { linkStart } from 'augma'
import { useRouter } from 'vue-router'

const router = useRouter()

function enter() {
  return linkStart(() => router.push('/guide/'), { waitFor: '.home' })
}
```

需要自己控制时机时，可以分步调用：`playLinkStart` 在屏幕被盖住时完成，并返回淡出函数。

```ts
import { playLinkStart } from 'augma'

const finish = await playLinkStart({ text: 'SYSTEM CALL' })
await router.push('/guide/')
await finish()
```

## API

### `linkStart(navigate, options?)`

播放隧道，屏幕被盖住后执行 `navigate`，再在新页面上淡出。返回的 Promise 在遮罩移除后完成。`navigate` 抛出错误时，遮罩仍会移除，错误继续向外抛出。上一次过场尚未结束时再次调用，返回同一个 Promise，不会重复跳转。

| 选项 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `text` | string | 'LINK START' | 中央文字；空字符串不显示 |
| `duration` | number | 1000 | 盖住屏幕所需的时间（毫秒） |
| `colors` | string[] | 深色主题的 `--agm-cyan`、`--agm-accent`、`--agm-highlight` 与 `--agm-text` | 光线颜色，接受任意 CSS 颜色 |
| `arrival` | string | 页面的 `--agm-bg` | 淡出前停留的颜色，应与目标页面背景一致 |
| `zIndex` | number | 1000 | 遮罩的层级 |
| `waitFor` | string | undefined | 等到没有元素匹配该选择器后再淡出 |
| `timeout` | number | 2000 | `waitFor` 的最长等待时间（毫秒） |

### `playLinkStart(options?)`

接受上表中除 `waitFor`、`timeout` 外的选项。屏幕被盖住时完成，返回 `finish(): Promise<void>`：调用后遮罩淡出并移除。

### `waitUntilGone(selector, timeout?)`

等到没有元素匹配 `selector`，或超过 `timeout`（默认 2000 毫秒）后完成。

## 无障碍与使用边界

- 开启减少动态效果时不播放隧道，`navigate` 立即执行；`playLinkStart` 立即返回空操作。
- 画布带 `aria-hidden="true"` 且不接收指针事件，不移动焦点；目标页面照常处理焦点与标题。
- 遮罩在淡出后移除；绘制失败、浏览器不支持 Canvas 2D 时也会立即移除，不阻塞跳转。标签页在后台暂停动画帧时，最多等待 `duration` 加 500 毫秒。
- 颜色取自深色主题的 tokens，字体取自 `--agm-font`，与页面当前是浅色还是深色无关。可以在 `[data-agm-theme='dark']` 上覆盖这些变量，或直接传入 `colors`。
- 未加载 `@augma/core/tokens.css` 时，使用深色主题的默认值。
- 适合一个产品里少数关键的进入时刻，例如「Link Start」入口；不要给每个链接都加上。

## 安装

```ts
import { linkStart, playLinkStart, waitUntilGone } from 'augma'
```

不使用 Vue 时，从 `@augma/core` 导入，它没有任何依赖：

```ts
import { linkStart } from '@augma/core/link-start'
```
