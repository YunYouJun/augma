# macOS 客户端

macOS 客户端把 [AR 演示](/guide/ar) 放进原生窗口：侧栏切换应用，界面离线可用；沉浸模式以透明悬浮层覆盖桌面，还可以用语音指令操作演示。

<div class="macos-downloads">
  <a class="agm-button agm-button--primary macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS-arm64.zip">下载 Apple 芯片版</a>
  <a class="agm-button agm-button--outline macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS-x86_64.zip">下载 Intel 版</a>
</div>

需要 macOS 26 或更高版本。请在「Apple 菜单 → 关于本机」查看芯片：Apple 芯片选择 arm64 版，Intel 处理器选择 x86_64 版。历史版本与各架构的 SHA-256 校验值见 [GitHub Releases](https://github.com/YunYouJun/augma/releases)。

## 安装与首次打开

1. 解压对应的 `Augma-macOS-arm64.zip` 或 `Augma-macOS-x86_64.zip`，把 `Augma.app` 拖到「应用程序」文件夹。
2. 双击打开。客户端尚未使用 Apple 开发者证书签名和公证，macOS 会提示无法验证，点击「完成」。
3. 打开「系统设置 → 隐私与安全性」，在「安全性」中点击「仍要打开」并确认。之后打开不再提示。

## 可以做什么

- **演示窗口**：在侧栏打开天气、声音、空间、摄像头、导航等应用，与网页版 AR 演示一致；工具栏可开启「始终置顶」。
- **沉浸模式**：界面以透明悬浮层覆盖当前显示器，空白区域点击穿透；右上角控制条可切换应用、操作桌面或退出。
- **语音指令**：点击左上角麦克风或按 `⌥⌘V`，说出「打开地图」「开始导航」等指令，也可以说英语或日语。首次使用时 macOS 会请求麦克风和语音识别权限。要换成其他按键，可在「系统设置 → 键盘 → 键盘快捷键 → App 快捷键」中为 Augma 添加菜单标题「开始或结束语音指令」。
- **多语言**：菜单与设置跟随 macOS 的语言（简体中文、English、日本語），可在「系统设置 → 通用 → 语言与地区 → 应用」中单独为 Augma 指定；演示界面的语言也可在其设置面板中切换。

摄像头和 WebXR 取决于 WebKit 对本地页面的支持，模拟界面不依赖这些权限。可选的 DeepSeek 助手能回答问题或执行演示操作，需要自备 API Key，详见[客户端说明](https://github.com/YunYouJun/augma/tree/main/apps/mac)。

## 从源码构建

需要 Node.js 24、pnpm 与 Xcode 26 或更高版本。在仓库根目录运行 `pnpm mac:run` 默认构建并启动 arm64 版；Intel Mac 开发者使用 `AUGMA_BUILD_ARCH=x86_64 pnpm mac:run`。`pnpm mac:package` 生成与发布相同的两个 Release 安装包 `apps/mac/dist/Augma-macOS-arm64.zip` 和 `Augma-macOS-x86_64.zip`，每个包附带 `.sha256`。只打包一种架构可运行 `pnpm mac:package arm64` 或 `pnpm mac:package x86_64`。
