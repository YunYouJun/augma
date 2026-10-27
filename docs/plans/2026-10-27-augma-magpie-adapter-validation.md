# Augma / Magpie 应用适配联调

日期：2026-10-27，Asia/Shanghai。

## 最终配置

`Augma → 本机 DSH 0.2.0-rc.2 → Magpie group/augma → codex/gpt-6.1-terra`，推理强度 `medium`。

Magpie 基于官方 `v0.1.1673` 构建本地 Augma adapter；运行时及凭据继续复用本机现有安装。初始进程仍运行 0.1.1293，但磁盘官方 bundle 已是 0.1.1673，最终适配按磁盘版本构建，没有回退到旧版。原官方 bundle 已备份。

## 界面与配置验证

- 在 Magpie Agent 列表看见 Augma 图标与卡片；选择 `Augma` 路由组后显示已接入。
- 展开卡片，调整推理强度 Medium → Low；Augma 检测后显示 `Augma · group/augma`、`Low`，模型和强度控件显示由 Magpie 管理。
- 点击「断开并还原」，核对配置恢复为原来的 `runtime=dsh`、`model=group/augma`、`effort=medium`，`managed` 字段移除。
- 从卡片直接选择 `GPT-6.1 Terra`，Augma 检测后显示 `codex/gpt-6.1-terra`，证实模型选择实际传播。
- 恢复 `group/augma`，在 Magpie 将强度设为 Medium；Augma 检测后正确显示路由组和 Medium，旧测试与启用状态失效。
- 运行正式 Augma 的「测试模型与只读工具」，真实调用 `system_summary`、`application_usage` 后返回回答。界面显示测试通过，随后启用助手。

## 网关证据

本次应用适配测试的请求由 Magpie usage API 读取，仅保留时间、应用、路由、模型、强度、状态和耗时；未保存账户、会话内容、凭据或工具返回的应用列表到仓库。

| 本地时间 | agent | 请求路由 | 实际模型 | 强度 | 状态 | 耗时 |
| --- | --- | --- | --- | --- | --- | --- |
| 12:13:58 | augma | group/augma | gpt-6.1-terra | medium | 200 | 2803 ms |
| 12:14:01 | augma | group/augma | gpt-6.1-terra | medium | 200 | 2425 ms |
| 12:18:16 | augma | group/augma | gpt-6.1-terra | medium | 200 | 2407 ms |

前两条为模型与工具测试，Magpie 当时为 `v0.1.1673-augma.3`。`.4` 加强非法配置的类型与格式校验，重新签名安装后确认卡片仍为已接入、Medium；12:18:16 从 Augma 正常文字入口发送确认请求，界面收到「连接正常。」，网关再次确认上述最终模型与强度。最终 `.5` 只替换 Augma SVG 图标为适配 Magpie 单色遮罩的透明标记；重启后已截图确认图标、模型和 Medium 正常显示。最终偏好为 `assistantRuntime=dsh`、`assistantDSHModel=group/augma`、`assistantDSHReasoning=medium`、`assistantDSHEnabled=true`。

## 自动检查

- Augma：完整 Swift 测试 348 项，7 项跳过，0 失败；3 项配置桥接测试覆盖首次导出、变更撤销、恢复、保留未知字段、冲突和非法配置。
- Augma：`./script/build_and_run.sh --verify` 通过，签名验证与正式 bundle 启动通过。
- Magpie：4 项适配测试覆盖注册、检测、模型/强度、断开恢复、拒绝非法配置和首次接入保留命名路由组。
- Magpie：Agent notice 与翻译键 UI 测试 26 项通过，覆盖 Chromium/WebKit 和 en/zh/zh-TW/ja/de。
- 首轮完整 Go 回归发现 adapter 将配置校验误用为网关地址 `Check`。已移除该钩子：Augma 不存网关地址，其路由由 DSH 管理；配置校验继续在每次编辑和 Augma 导入时执行。修复后完整 `internal/agent` 测试通过。
- macOS 原生 vet、Linux/Windows cross vet 和三平台构建均通过；本地 app bundle 签名验证通过。
- 全量检查另发现原有 `TestUnreadLoginsWriteErrorsKeepCredentials` 在不同 synctest bubble 中关闭共享 `filememo.Written` 通道而崩溃。测试已通过只读目录阻止备份，无需固定时间；移除虚拟时钟并按备份路径前缀断言，保留原有文件和错误检查。修复单独保存为测试补丁，不修改生产登录代码；`-race -count=20` 通过。
- 最终 `go test -p 4 -tags nogui -timeout 45m ./...` 全量通过，退出码 0：74 个有测试的包通过，18 个包无测试；使用隔离 HOME 和固定工具链缓存。两份补丁已共同验证可应用到官方 `v0.1.1673`，`gofmt` 与 `git diff --check` 通过。

## 交付边界

这是本地适配构建，尚未发布或向上游提交。官方升级会替换自定义 adapter；本地签名与官方签名不同，自动更新已观察到团队校验拒绝，未修改签名验证。重建、使用和回退步骤见[适配说明](../../integrations/magpie/README.md)。其他运行时、清理、语音和 UI 的已有未提交改动保留，未混入 Magpie 补丁。

Magpie 本地分支 `codex/augma-agent-adapter-1673` 已分别保存提交：`b2d30cd`（原有登录测试隔离修复）与 `8226c8e`（Augma adapter）。源码位于本机 `repos/github.com/yetone/magpie-augma`。Augma 端改动保留在当前工作区，未把已有其他改动一并提交。
