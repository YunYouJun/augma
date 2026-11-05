# Augma Link 网页插件 v1

Augma Link 的第三方插件是独立的本地网页包。用户安装自己的 HTML / CSS / JavaScript 后启用，在 Augma 内打开或加入 Dock；插件内容不需要编译进原生可执行文件。

支持在线目录查询、下载并安装，以及从本地文件夹安装。在线下载与本地导入共用安装、启用、停用、卸载流程。自动更新、ZIP 导入、作者签名认证、原生插件代码和原生权限接口尚未接入。清单中的作者是包作者声明的元数据。

## 技术栈与仓库组织

插件使用标准 HTML / CSS / JavaScript，宿主使用 SwiftUI / WebKit。首个示例没有框架或 npm 运行依赖；后续可用 Vue、React、TypeScript 等生成静态资源，只要产物遵守本包的路径、CSP 与权限约定。

插件放在当前 monorepo 的 `plugins/*`，每个目录是独立版本的 pnpm workspace 包。呼吸环位于 `plugins/breathing-orbit`，工作区包名为 `@augma/plugin-breathing-orbit`；版本与插件清单一致，不随宿主版本同步。`private: true` 表示不发 npm，发布目标是 Augma Link 的静态目录。第三方作者也可以在自己的仓库生产相同格式的插件包。

依赖锁文件包含呼吸环的空 workspace 条目，以兼容仓库固定的 pnpm 12.5.1；新增无依赖插件时也需确认干净的 `pnpm install --frozen-lockfile` 能通过。

## 远程目录与分发

默认目录地址为 `https://augma.yyj.moe/plugins/catalog.json`，随现有 Cloudflare Pages 站点发布。宿主获取目录后按名称、简介、ID 筛选；安装按钮再下载对应包，不执行下载内容。目录只展示元数据，不托管服务端查询接口。

```sh
pnpm plugins:build  # 生成 apps/site/public/plugins
pnpm build          # 站点构建会自动生成并包含插件目录与包
pnpm test:plugins
```

构建器读取每个 workspace 的 `augmaPlugin.source`，检查发布文件夹，生成确定性的 JSON 文件容器。使用文件字节的 Base64 表示，不依赖 ZIP 解压工具。包地址包含 ID、版本和内容 SHA-256；同次本地构建中旧内容地址保留，干净的站点构建包含当前源包。

```json
{
  "schemaVersion": 1,
  "plugins": [{
    "manifest": { "schemaVersion": 1, "id": "org.example.clock", "name": "Clock", "version": "1.0.0", "author": "Example", "summary": "A clock", "entry": "index.html", "symbol": "clock", "permissions": [] },
    "packageURL": "packages/org.example.clock/1.0.0/<sha256>.augmaplugin.json",
    "size": 1234,
    "sha256": "<64 lowercase hex characters>"
  }]
}
```

容器格式为 `{ "format": "augma-web-plugin", "schemaVersion": 1, "files": [{ "path": "index.html", "data": "<base64>" }] }`。目录最多 512 KiB、128 个条目，下载容器最多 12 MiB。网络客户端使用无 Cookie、无凭据缓存的临时会话，拒绝重定向，只接受目录所在路径下、同源的 HTTPS 包。下载按流限制大小，可取消；大小、SHA-256、资源路径和包内清单全部匹配后，才进入原子安装流程。失败或取消不留下安装记录，临时文件会被清理。

SHA-256 验证的是来自可信 HTTPS 目录的内容完整性，不代表第三方作者身份经过认证。安装后默认停用，点击启用后才能打开和加入 Dock。

本地分发联调可运行 `python3 -m http.server 8765 --bind 127.0.0.1 --directory apps/site/public`，再启动 Debug App：

```sh
AUGMA_PLUGIN_CATALOG_URL=http://127.0.0.1:8765/plugins/catalog.json \
AUGMA_PLUGIN_ALLOW_LOCAL_HTTP=1 pnpm mac:run
```

HTTP 例外只在 Debug 构建且显式设置开关时对回环地址有效。Release 构建始终要求 HTTPS。`AUGMA_PLUGIN_CATALOG_URL` 也可指向 HTTPS 的预览目录，无需修改源码。

## 包结构

```text
Example.augmaplugin/
  augma-plugin.json
  index.html
  style.css
  main.js
```

`.augmaplugin` 是文件夹名称约定，也可导入普通文件夹。清单示例见[呼吸环清单](../plugins/breathing-orbit/BreathingOrbit.augmaplugin/augma-plugin.json)。

| 字段 | v1 约定 |
| --- | --- |
| `schemaVersion` | 固定为 `1`，不兼容版本拒绝安装 |
| `id` | 稳定的小写标识，例如 `org.example.clock`，最多 160 字符；作为安装身份 |
| `name` | 展示名称，最多 60 字符 |
| `version` | `major.minor.patch` 数字版本，例如 `1.0.0` |
| `author` | 作者名称，最多 80 字符 |
| `summary` | 用途说明，最多 240 字符 |
| `entry` | 包内 HTML 相对路径，例如 `index.html` |
| `symbol` | SF Symbols 图标名称 |
| `permissions` | 当前必须为 `[]`，其他值拒绝安装 |

最多 256 个文件、总计 8 MiB、单个文件最多 2 MiB；目录深度最多 8 层。只接受 HTML、CSS、JS、JSON、TXT、SVG、PNG、JPEG、GIF、WebP、WOFF 和 WOFF2。包内不允许软链接、硬链接或特殊文件；路径不允许绝对路径、`..`、空段、反斜线、控制字符、`%`、`:`、`?` 或 `#`。清单最多 32 KiB。请提供干净的发布文件夹，不包含 `.git`、`node_modules` 或 Finder 元数据。

## 生命周期

- **安装**：校验清单与资源，复制至 Augma 的暂存目录，重新校验后提交安装副本与注册表。初始停用，不执行网页代码。同 ID 的第二次安装会拒绝，需先卸载旧版本。
- **启用**：持久化启用状态，允许打开页面与加入 Dock。不会在后台自动启动网页。
- **打开**：创建独立 WebKit 会话，读取已安装副本，运行入口 HTML。每个窗口有独立的网页状态。
- **停用**：持久化停用状态，关闭所有窗口中该插件的页面，移除它的 Dock 入口。再次启用后可以重新固定。
- **卸载**：移除注册记录、安装副本、运行页面和 Dock 入口；原始导入文件夹保留。注册表提交失败时恢复安装副本。

状态存于 `~/Library/Application Support/Augma/Link/plugins.json`，安装副本存于同目录的 `Packages/<id>.augmaplugin`。安装、启用、停用和卸载都由一个应用级 store 协调，主窗口与沉浸模式共享安装状态。写入失败显示错误；损坏注册表保留并阻止覆盖。单个安装包损坏或丢失时标记为不可用，仍可停用、卸载。

## 网页运行接口

插件以 `augma-plugin://<id>/<entry>` 加载。资源处理器只返回经过校验的文件清单中的资源，不提供其他插件、宿主文件或系统文件。所有 HTML 在作者标记之前加入宿主 CSP：脚本、样式、字体、媒体和 `fetch` 只允许本包资源；图片额外允许 `data:`。使用独立 JS/CSS 文件，不使用内联脚本、内联样式或 `eval`。

外部导航、弹窗、嵌入框架、worker、表单提交和远程请求被禁用。没有原生消息桥、shell、文件系统或系统状态接口；摄像头、麦克风、位置和剪贴板能力不会授予插件。网页使用非持久数据存储，与 Augma 的普通浏览器会话分离。关闭、停用或卸载会替换运行文档并释放页面。首版不提供持久化插件设置；主窗口与沉浸模式之间切换会重建页面。

实现基于 Apple 的 [WKURLSchemeHandler](https://developer.apple.com/documentation/webkit/wkurlschemehandler) 和 [WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)。运行测试会加载真实 WebKit 页面，验证本地脚本可执行、CSP 报告外部请求被拒绝、关闭后旧 JavaScript 上下文消失。

## 开发与验证

复制[呼吸环包](../plugins/breathing-orbit/BreathingOrbit.augmaplugin)，修改清单中的 ID、名称和入口内容，再用 Augma Link 的「从文件夹安装…」导入。改动源码不会改变已经安装的副本，需卸载后重新安装。

```sh
swift test --package-path apps/mac --filter AugmaPlugin
pnpm exec eslint plugins/breathing-orbit
pnpm test:plugins
```

`script/build_and_run.sh` 将示例包复制到 App 的 `Resources/LinkCatalog`，用于「离线示例 → 安装示例插件」。安装仍经过与外部文件夹相同的校验和复制流程。公开站点发布后，可设置 `AUGMA_TEST_REMOTE_PLUGIN_CATALOG=1 swift test --package-path apps/mac --filter AugmaPluginDistributionTests` 验证真实远程目录与下载。
