# macOS 客户端

macOS 客户端把 [AR 演示](/guide/ar) 放进原生窗口：侧栏切换应用，界面离线可用；沉浸模式以透明悬浮层覆盖桌面，还可以用语音指令操作演示。

<a class="agm-button agm-button--primary macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS.zip">下载 Augma for macOS</a>

需要 macOS 15 或更高版本，Apple 芯片与 Intel 芯片的 Mac 均可使用。历史版本与 SHA-256 校验值见 [GitHub Releases](https://github.com/YunYouJun/augma/releases)。

## 安装与首次打开

1. 解压 `Augma-macOS.zip`，把 `Augma.app` 拖到「应用程序」文件夹。
2. 双击打开。客户端尚未使用 Apple 开发者证书签名和公证，macOS 会提示无法验证，点击「完成」。
3. 打开「系统设置 → 隐私与安全性」，在「安全性」中点击「仍要打开」并确认。之后打开不再提示。

## 可以做什么

- **演示窗口**：在侧栏打开天气、声音、空间、摄像头、导航等应用，与网页版 AR 演示一致；工具栏可开启「始终置顶」。
- **沉浸模式**：界面以透明悬浮层覆盖当前显示器，空白区域点击穿透；右上角控制条可切换应用、操作桌面或退出。
- **语音指令**：点击左上角麦克风或按 `⌘⇧V`，说出「打开地图」「开始导航」等指令，也可以说英语或日语。首次使用时 macOS 会请求麦克风和语音识别权限。
- **多语言**：菜单与设置跟随 macOS 的语言（简体中文、English、日本語），可在「系统设置 → 通用 → 语言与地区 → 应用」中单独为 Augma 指定；演示界面的语言也可在其设置面板中切换。

摄像头和 WebXR 取决于 WebKit 对本地页面的支持，模拟界面不依赖这些权限。可选的 DeepSeek 助手能回答问题或执行演示操作，需要自备 API Key，详见[客户端说明](https://github.com/YunYouJun/augma/tree/main/apps/mac)。

## 从源码构建

需要 Node.js 24、pnpm 与 Xcode。在仓库根目录运行 `pnpm mac:run` 构建并启动；`pnpm mac:package` 生成与发布相同的通用安装包 `apps/mac/dist/Augma-macOS.zip`。
