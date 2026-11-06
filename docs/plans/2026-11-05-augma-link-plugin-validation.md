# Augma Link 网页插件首轮验收

2026-11-05，在独立原生验收包中完成 Breathing Orbit（呼吸环）的安装、启用、停用与卸载。验收使用独立 bundle ID 和临时用户目录，未替换日用安装。

示例位于 `plugins/breathing-orbit/BreathingOrbit.augmaplugin`，由清单、HTML、CSS 与 JavaScript 四个文件组成。构建脚本将其作为本地目录条目复制进 App 的 `Resources/LinkCatalog`，安装时通过与第三方文件夹相同的校验、暂存、复制与注册流程。

| 操作 | 观察结果 |
| --- | --- |
| 点击安装示例插件 | 出现已安装记录，初始显示“已停用”，没有 Dock 入口 |
| 退出并重新启动验收包 | 已安装记录及停用状态恢复 |
| 启用 | 显示“已启用”，出现打开与加入 Dock 操作 |
| 加入 Dock | 新增独立的呼吸环图标，固定按钮变为不可点击 |
| 从 Dock 打开 | 加载 `augma-plugin://org.augma.examples.breathing-orbit/index.html`，显示完整圆环页面 |
| 点击开始、暂停 | 页面显示吸气倒计时，按钮切换暂停／继续；环形动画运行 |
| 返回管理并停用 | 状态恢复“已停用”，打开和固定操作隐藏，Dock 图标消失 |
| 卸载并确认 | 已安装列表为空，示例安装按钮恢复；注册表为空，管理的包目录消失，仓库原始包仍存在 |

自动化回归覆盖安装、启用与停用的重启恢复、重复 ID、注册写入失败回滚、损坏注册表保护、丢失安装包的管理、跨窗口关闭与 Dock 清理。文件校验覆盖路径穿越、软链接、硬链接和资源大小限制。真实 WebKit 测试验证本地脚本运行、`connect-src` 策略拒绝外部请求、标准文档模式、关闭后旧 JavaScript 上下文消失，以及独立的非持久会话。

原生全量测试、发布打包测试、示例 ESLint 与 AX 契约检查均已执行。发布测试额外确认示例清单和 JavaScript 会进入 App 资源。新管理按钮在真实 AX 树中分别具有独立标识；没有声称验证 VoiceOver 播报。

当前不提供 ZIP 导入、自动升级、作者签名认证、原生权限、宿主消息桥或插件持久化设置。启用只开放入口，页面打开时才运行；关闭或切换主窗口／沉浸模式会重建网页会话。最低支持系统的独立设备验收不在本次验证范围。

## 远程分发补充验收

呼吸环已迁入 `plugins/breathing-orbit` 独立 pnpm workspace。`pnpm plugins:build` 生成静态目录与内容地址化的 JSON 下载包，`pnpm build` 将其与 Cloudflare Pages 站点一起打包。

独立 bundle `cn.yunyoujun.augma.remote-plugin-review` 使用 `/tmp/augma-remote-plugin-review/home`，通过 Debug 的显式回环 HTTP 开关连接生成目录。真实界面验证：

- 搜索不存在的插件显示无结果；搜索“呼吸”显示呼吸环。
- 点击在线卡片的「下载并安装」，读取 10,185 字节包并完成大小与 SHA-256 校验，记录初始停用；在线卡片变为不可点击的「已安装」。
- 启用、加入 Dock、从 Dock 打开，加载安装副本中的独立 WebKit 页面，开始／暂停按钮正常切换。
- 停用后 Dock 图标消失；卸载并确认后在线下载按钮恢复，注册表为 `{"version":1,"plugins":[]}`，管理的 Packages 目录为空，仓库源码仍存在。
- 刷新目录可再次获得示例条目。AX 树可读取独立的在线搜索、刷新和下载按钮标识。

分发测试使用真实回环 HTTP 服务，覆盖目录查询、下载、校验、安装与启停卸载、错误哈希、重定向、跨源地址、超限响应、路径穿越、重复与大小写冲突、清单身份不符，以及取消下载不产生安装记录。Node 构建测试验证可复现产物、内容地址、workspace 与清单版本一致、权限和链接检查。macOS 默认文件系统无法创建仅大小写不同的两个文件，因此 Node 的大小写磁盘用例跳过；Swift 容器用例仍完整验证此限制。

原生全量 513 项，0 失败、13 项条件跳过；完整 `pnpm check` 通过，包括 226 项单元测试、23 项发布测试、206 项浏览器测试（4 项条件跳过）、插件构建测试、类型检查、ESLint、生产构建、npm 包与组件 Registry 验证。AX 契约检查通过。公网 HTTPS 默认地址是 `https://augma.yyj.moe/plugins/catalog.json`；正式发布与真实 HTTPS 验收见下节。

包协议和使用说明见[插件开发说明](../plugins.md)与[示例 README](../../plugins/breathing-orbit/README.md)。


## 正式发布与 HTTPS 验收

2026-11-05，完成 Cloudflare 登录后，通过现有 GitHub → Pages 流程发布。[PR #10](https://github.com/YunYouJun/augma/pull/10) 已合并，生产提交为 `9bf732cf5ba924e51cbabce78eb07d991c65879c`，Cloudflare 生产部署为 `d52579c2-40ee-422b-8df1-3c0730f62769`，状态 success。发布分支使用独立 worktree，只包含插件源码、构建器、目录配置与必要的干净安装／签名测试修复。合入的文件树与已通过 PR CI 的文件树一致。

- 目录：[catalog.json](https://augma.yyj.moe/plugins/catalog.json)。响应为 200，缓存为 `public, max-age=0, must-revalidate`。
- 呼吸环 `1.0.0` 下载容器为 10,185 字节，SHA-256 为 `7e6282b5360cf8b57647f0f89b9195c0f23b9508beee9a1cde03a7674f0de533`。实际 HTTPS 下载的大小与哈希一致，缓存为 `public, max-age=31536000, immutable`。
- 正式域名的首页、`/ar/`、`/components.json`、`/r/button.json`、`/llms.txt` 均返回 200。
- 原生界面连接正式目录，搜索呼吸环、下载并安装为停用状态、启用、加入 Dock、从 Dock 打开、开始、停用和确认卸载均通过。卸载后 Dock 入口移除，在线卡片恢复「下载并安装」。
- Debug 预览使用独立 bundle ID；重启进程后 `CFFIXED_USER_HOME` 没有继续隔离插件安装目录，最后一轮界面验收实际写入默认 `~/Library/Application Support/Augma/Link`。只安装并卸载了本示例，验收结束后已核对注册表无安装记录、Packages 目录为空，源码保留。不要只依赖 bundle ID 或此环境变量隔离后续验收。
- 启用公网检查后，最终原生全量 539 项，0 失败、14 项条件跳过。公网用例用真实客户端下载，并在明确的临时仓库内完成安装、启用、停用、卸载；另验证篡改、重定向、限制与取消场景。
- 干净的 `pnpm install --frozen-lockfile` 和完整 `pnpm check` 通过。GitHub CI 通过：226 项单元测试、5 项插件构建测试、19 项发布测试（2 项 macOS 条件跳过）、194 项浏览器测试（16 项条件跳过）。本机同一发布树为 209 项浏览器测试通过、1 项条件跳过。
- Cloudflare Pages 与 GitGuardian 检查通过。仓库另外连接的 Netlify 预览检查报 Deploy failed；该非必需集成未用于本次正式发布。

`pnpm-lock.yaml` 补充无依赖插件的空 importer，以兼容固定 pnpm 12.5.1 的 frozen install。构建器、示例和分发测试已经进入 CI；后续修改 `plugins/*` 后通过站点构建继续发布。
