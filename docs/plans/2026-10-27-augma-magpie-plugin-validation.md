# Augma / 官方 Magpie 插件迁移验证

日期：2026-10-27，macOS arm64。本机已恢复官方 Magpie 0.1.1673，继续复用 DSH 0.2.0-rc.2。

## 最终状态

- `/Applications/magpie.app` 已通过 `codesign --verify --deep --strict`，Team ID `LY7MVTUDZG`；可执行文件 SHA-256 与原官方备份完全一致。官方更新已正常下载并提示可重启更新，未跳过签名验证、未执行额外升级。
- 已停用并备份本地 `v0.1.1673-augma.5` 包；本轮未修改 Magpie 源码，开发 checkout 保持干净。
- 独立包 `integrations/magpie/magpie-plugin-augma` 已复制到本机 Augma 的 `Integrations` 目录，并通过官方 CLI 安装启用。
- `group/augma` 保留手动路由到 `codex/gpt-6.1-terra`，推理强度 Medium，Augma 助手已通过测试并启用。

## 实际验证

1. 在官方 Magpie 的 Augma 卡片选择 GPT-6.1 Terra，Augma 设置实时导入 `codex/gpt-6.1-terra` 并撤销旧测试；随后从卡片切回 Augma 专属路由组。
2. 在 Agent 页插件面板保存 Low；Augma 检测显示 Low，两项只读工具 `system_summary`、`application_usage` 测试通过。
3. 在同一面板恢复 Medium；Augma 旧测试状态被撤销，重新检测与工具测试通过，再启用助手。
4. 额外直接向本机网关发出标记为 Augma、请求强度 High 的普通文本请求；插件实际覆盖为 Medium，HTTP 200，回答 `AUGMA_PLUGIN_OK`。证明 middleware 在官方网关中运行。
5. Augma 普通文字输入「请只回复一句中文确认插件连接正常，不调用工具。」得到「插件连接正常。」；真实调用 HTTP 200 / Terra / Medium。
6. 使用官方 CLI 断开插件管理，核对配置精确恢复为接入前四项；重新连接完整的 `magpie/group/augma` 后保留 Medium 和专属路由。

## 请求记录（仅保留非敏感字段）

| 时间（+08:00） | 请求路由 | 实际模型 | 强度 | HTTP | 耗时 ms |
| --- | --- | --- | --- | --- | --- |
| 13:15:01 | `group/augma` | `gpt-6.1-terra` | low | 200 | 3432 |
| 13:15:04 | `group/augma` | `gpt-6.1-terra` | low | 200 | 2896 |
| 13:15:28 | `group/augma` | `gpt-6.1-terra` | medium | 200 | 3244 |
| 13:15:32 | `group/augma` | `gpt-6.1-terra` | medium | 200 | 2342 |
| 13:16:06 | `group/augma` | `gpt-6.1-terra` | medium | 200 | 2880 |
| 13:16:47 | `group/augma` | `gpt-6.1-terra` | medium | 200 | 3201 |

## 自动验证

- 插件 Node 测试：4 项通过，覆盖接入无凭据、Chat/Responses、无关应用不变、默认值和非法强度。
- 联调时完整工作区 Swift 全量：350 项，7 项跳过，0 失败；其中 5 项配置同步回归覆盖外部变更、断开、丢失/关闭/重复/非法插件配置。
- 提交前单独导出暂存快照：Swift 294 项，5 项跳过，0 失败；插件 Node 4 项通过。该快照排除了清理、市场、全局布局等其他未提交功能，仅保留 DSH 接入所需依赖，并将 DSH 版本探测从清理命令运行器中独立出来。
- `./script/build_and_run.sh --verify` 构建、签名、启动通过。
- 官方 Magpie 原生 WKWebView 实际操作，验证插件控件加载、保存、模型选择、配置同步。

## 证据保留

原生窗口截图及经过字段筛选的请求摘要保留在本机。本提交仅保留上述验收结果，不包含机器绝对路径、原始请求日志、会话文件、截图或账户配置。

## 使用范围

模型选择器使用官方 Agent 插件能力，推理强度位于插件面板/插件页；官方卡片内的内置 effort 控件并未修改。插件从本地目录安装，未发布到 npm/插件市场。验证版本为官方 0.1.1673，未把尚未安装的更新版本视为已验证。DSH 固定兼容 0.2.0-rc.2，插件配置读取默认或绝对 `XDG_CONFIG_HOME` 路径；Magpie portable 目录不自动发现。

安装、管理及卸载见 [插件说明](../../integrations/magpie/README.md)。

## 独立远端分支验证

为仅推送本次迁移，从远端 `main`（`0dc8acd`）建立独立分支并移植 `dd7d32a`。没有移植本地天气、监控仪表盘或全局布局提交。

原迁移的原生只读工具引用了后续监控提交才具有的接口。此分支仅补齐 `ApplicationMemory.swift` 的只读采样实现及其回归测试，并将摘要工具接到远端已有的 `SystemMetricsReader.sample(includeDisks:)`。不包含监控页面、传感器或后台采样开关改动。三份翻译冲突仅保留远端已有内容与 DSH/Magpie 助手新增条目。

在该独立分支执行 Swift 全量测试：272 项，4 项跳过，0 失败；插件 Node 测试 4 项通过。此项验证不依赖本地 `main` 中的其他提交或未提交文件。
