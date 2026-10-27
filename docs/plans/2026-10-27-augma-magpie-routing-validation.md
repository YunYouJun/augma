# Augma 专属 Magpie 路由联调

日期：2026-10-27，Asia/Shanghai。按用户要求配置本机 Magpie，并通过正式 Augma 应用完成真实模型与原生工具联调。

## 已生效配置

```text
Augma → 本机 DSH 0.2.0-rc.2 → Magpie group/augma → codex/gpt-6.1-terra
```

| 项目 | 配置 |
| --- | --- |
| Magpie | 0.1.1293，网关 `http://127.0.0.1:3425` |
| 路由组 | 名称 `Augma`，模型 ID `group/augma` |
| 路由策略 | `manual`，选中 `codex/gpt-6.1-terra`，`stays=session` |
| Augma 推理选项 | `medium` |
| DSH 路径 | 自动检测 `/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh` |
| Augma 状态 | 模型与两项只读工具测试通过，助手已启用 |
| 使用归属 | Magpie usage 中 `agent=augma` |

此配置保存在本机 Magpie 和 Augma 偏好中，不是应用发行版的全局默认值。复用已安装的 DSH 可执行文件；Augma 仍使用隔离 profile，不改写 DSH 桌面的模型设置。其他 Magpie 路由组及凭据保持原有配置。

最初创建时使用 Luna 完成下述联调，随后按用户要求切换为 GPT-6.1 Terra。创建前已确认不存在同名组。Magpie 的 `group add` 会覆盖同名组，已有组应先检查再按需使用 `group set` / `group pick`。

```sh
"/Applications/magpie.app/Contents/MacOS/magpie" group add Augma models=codex/gpt-6-luna routing=manual stays=session
"/Applications/magpie.app/Contents/MacOS/magpie" group pick augma codex/gpt-6-luna
```

## Luna 首次联调

- `/api/hello` 确认 Magpie 身份；`/v1/models` 已公布 `group/augma`，推理选项包含 `low`。
- 在正式 Augma 设置页检测 DSH、选择 `Augma · group/augma`、重新读取推理选项、选择 Low。
- 11:22 的“测试模型与只读工具”真实调用 `system_summary` 和 `application_usage`，界面显示测试通过，随后启用助手。
- 11:23 在正常文字入口询问系统内存压力与应用占用，Augma 返回实时指标和释放内存建议。
- 两次联调共 4 条 Magpie 模型请求，`requested_model=group/augma`、`provider=codex`、`served_model=gpt-6-luna`、`effort=low`、`status=200`、`swapped=false`。
- 通过进程父子关系确认 DSH 由正式 Augma 应用启动；用户偏好中已持久化路由组、Low、测试指纹与启用状态。

本次无需修改运行时代码或重新构建。验证覆盖配置持久化、实际路由组解析、工具往返和正常文字问答；没有录音、清理文件或改动其他应用。截图及去除账户信息的 usage 摘要保留在本次 Codex 本地附件目录，不将本机会话或凭据写入仓库。

## 默认模型切换为 GPT-6.1 Terra

刷新 Magpie 模型目录后，Codex 来源公布 `codex/gpt-6.1-terra`，支持 Low 推理。通过以下命令更新既有组，保留 `manual`、`stays=session` 和 Augma 中的 Low 设置：

```sh
"/Applications/magpie.app/Contents/MacOS/magpie" sync
"/Applications/magpie.app/Contents/MacOS/magpie" group set augma models=codex/gpt-6.1-terra pick=codex/gpt-6.1-terra
```

在正式 Augma 中重新检测连接并运行模型与两项只读工具测试，界面确认通过，助手保持启用。11:31:54 和 11:31:58 的两条请求均为 `requested_model=group/augma`、`served_model=gpt-6.1-terra`、`effort=low`、`status=200`、`swapped=false`。

## 推理强度切换为 Medium

按用户要求在正式 Augma 设置页选择 Medium，并重新运行模型与两项只读工具测试。首次测试于 11:34 成功调用两项工具，但最终回答请求发生 `TRANSPORT / Connection error`，因此 Augma 正确保持未启用状态。重试后完整测试通过，随后重新启用助手。

11:35:49 和 11:35:52 的两条成功请求均为 `requested_model=group/augma`、`served_model=gpt-6.1-terra`、`effort=medium`、`status=200`、`swapped=false`。本机偏好已持久化 `assistantDSHReasoning=medium`，测试指纹与当前配置一致，`assistantDSHEnabled=true`。

以后可在 Magpie 的 Augma 路由组中调整成员与手动选中模型；变更后在 Augma 设置页重新检测、核对推理选项并运行工具测试。
