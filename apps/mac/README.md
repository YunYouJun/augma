# Augma macOS demo

原生 macOS 演示窗口使用 SwiftUI 侧栏选择应用，WebKit 展示与 `apps/ar` 相同的界面。天气、声音、空间、摄像头、导航和系统应用均可从侧栏打开；在演示画面中点击应用图标，也会同步原生侧栏的选择。

点击主窗口工具栏的「沉浸模式」，界面会以透明悬浮层覆盖当前显示器的可用桌面区域。原窗口暂时隐藏，退出后恢复。空白区域默认允许点击穿透，应用面板和按钮仍可操作；右上角的原生控制条可切换应用、选择「操作桌面」让所有区域穿透，或退出沉浸模式。菜单栏中的 Augma 菜单也提供这些操作。应用面板使用失焦后仍保持模糊的原生材质；控制条在 macOS 26 上使用 Liquid Glass，失焦后同样保持模糊，在 macOS 15 上与应用面板使用同一种材质。

需要 macOS 15、Node.js 24 和 pnpm。在仓库根目录运行 `pnpm mac:run` 可打包并启动；运行 `pnpm mac:verify` 可额外检查进程和演示窗口。两条命令都调用 `script/build_and_run.sh`。脚本会将 AR 站点构建为相对路径资源，与 SwiftPM 可执行文件一同放入 `apps/mac/dist/Augma.app`，界面可离线展示。运行 `pnpm mac:package` 则构建 Apple 芯片与 Intel 通用的 Release 版本，进行 ad-hoc 签名并压缩为 `apps/mac/dist/Augma-macOS.zip`（附 `.sha256`），版本号取自根目录 `package.json`。

App 图标是深蓝底板上的白色字母 A，外围是与原生 `AugmaRing` 同款的环形 HUD：青色细环和两段相对的圆头橙色弧。原稿归档在 [YunLeFun/icons](https://github.com/YunLeFun/icons/tree/main/assets/apps/augma/v1)（`ylf:augma-app-icon` / `ylf:augma-mark`），`assets/brand` 保存固定版本的副本与同一份 SHA-256 清单：`pnpm icons:check` 校验本地副本，`pnpm icons:sync --source /path/to/YunLeFun/icons` 从中心原稿更新。打包脚本先校验清单，再用 Xcode 26 及以上的 `actool` 把分层的 `Augma.icon` 编译为 `Assets.car`，供 macOS 26 的默认、深色、Clear 与着色外观使用；`AppIcon.icns` 由 `augma-app-icon.svg` 按 Apple 1024 px 模板渲染，作为 macOS 15 和旧工具链的兜底。

菜单栏中的 Augma 菜单可重新打开演示窗口，也保留了原有的辅助 HUD 浮窗与鼠标穿透开关；HUD 浮窗在 macOS 26 上同样使用 Liquid Glass。辅助 HUD 的 RealityKit 场景只在用户主动进入演示空间时创建。

主窗口工具栏和菜单栏都提供「始终置顶」开关；开启后演示窗口会显示在其他普通窗口上方，设置会在下次启动时保留。辅助 HUD 和沉浸模式的悬浮层保持各自原有的显示方式。

摄像头和 WebXR 仍取决于 WebKit 对本地页面及设备权限的支持；应用选择和模拟界面不依赖这些权限。沉浸模式的 WebView 透明背景使用 WebKit 的非公开 `_setDrawsBackground:` 方法，系统升级后需要重新验证。推送 `v*` 标签时，发布工作流会把同一个压缩包附加到该版本的 GitHub Release，站点的[下载页](https://augma.yyj.moe/guide/macos)指向最新版本。安装包尚未使用 Developer ID 签名和公证，首次打开需在「系统设置 → 隐私与安全性」中点击「仍要打开」。

## 语音指令

点击界面左上角麦克风，选择「开始语音识别」，说出指令后点击「结束并执行」。也可在 App 内按 `⌥⌘V`（「语音」菜单）打开指令面板并开始录音，再按一次结束并执行；等待权限或识别结果时再次按下会取消。默认不用 `⇧⌘V`，因为 Paste、Pastebot 等剪贴板工具把它注册为全局快捷键，按下后 Augma 收不到。要换成其他按键，可在「系统设置 → 键盘 → 键盘快捷键 → App 快捷键」中为 Augma 添加菜单标题「开始或结束语音指令」（English 界面为 “Start or Finish Voice Command”，日本語界面为「音声コマンドを開始／終了」）；演示界面的快捷键列表和指令面板会显示菜单当前的按键。首次使用时，macOS 会请求麦克风和语音识别权限。语音识别由系统 Speech 框架完成，识别语言跟随演示界面当前的语言（简体中文、English 或日本語）：设备支持该语言的离线识别时优先在设备上处理，否则可能使用 Apple 在线识别服务。一次录音最多约 12 秒；切换应用或关闭指令面板会停止录音。

目前支持打开地图、扫描空间、播放或暂停声音、显示或隐藏 HUD、打开天气示例 / 通知 / 设置 / 摄像头面板、切换深色或浅色视界，以及对当前选中地点开始模拟导航、前进一步、结束导航。语音不会自行开启摄像头。识别文字会显示在面板中；也可以手动输入指令或点击示例按钮，不需要麦克风。在浏览器中打开的网页演示改用浏览器自带的语音识别，点击开始后才请求麦克风权限。执行后会用 WebKit 的语音合成朗读结果或助手的回复，可在演示设置中关闭「语音播报」；开始录音时会先停止朗读，避免被麦克风收进去。

## 多语言

原生菜单、设置窗口和权限说明提供简体中文、English 与日本語，跟随 macOS 的首选语言，也可在「系统设置 → 通用 → 语言与地区 → 应用」中为 Augma 单独指定。字符串表位于 `apps/mac/Localization/*.lproj`，以 Swift 源码中的简体中文原文为键，由 `script/build_and_run.sh` 复制进 App 包。内置网页启动时会收到 App 当前的语言；用户在演示设置中另选的语言会保存在网页中并优先使用。原生端只回传错误代码，提示文字由网页按当前语言显示。

默认只在本机按上述规则匹配指令。需要理解其他说法或回答问题时，可在 App 菜单的「设置」中输入自己的 DeepSeek API Key，并打开「使用 DeepSeek 助手回答未匹配的指令」。只有无法在本机匹配的指令文字会连同最近四轮对话发送至 [DeepSeek Chat Completions API](https://api-docs.deepseek.com/api/create-chat-completion/)（`deepseek-flash`）。提示词与回答格式由内置网页的 `apps/ar/src/features/device/assistant.ts` 统一维护，浏览器与 App 共用；密钥保存在 macOS 钥匙串，不传给网页：原生端只校验网页传来的对话消息，固定模型与长度上限后附上密钥发送，再把回答交回网页。助手用一两句话作答，回复显示在面板中并朗读；也可以选择一个演示指令，返回值必须在上述操作白名单内，结果由演示界面播报。格式错误或请求失败时不执行操作。DeepSeek API 需要自行申请密钥，调用可能收费，具体以[官方模型与价格页](https://api-docs.deepseek.com/quick_start/pricing/)为准。本地指令在未配置或未开启 DeepSeek 时照常可用。
