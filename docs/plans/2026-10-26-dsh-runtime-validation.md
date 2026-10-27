# DSH / ACP / Magpie 验证记录

日期：2026-10-26。关联 [Issue #9](https://github.com/YunYouJun/augma/issues/9) 与[实施计划](./2026-10-26-dsh-runtime-goal.md)。本记录区分真实联调、协议夹具和代码检查；未用模拟服务替代真实模型验收。

## 结论与支持范围

首版采用 **ACP over stdio**，在本机已验证 Augma → DSH → Magpie → 已配置模型 → 原生 MCP 工具 → 最终回答。无需 DSH 桌面窗口，也无需第二种 harness 或传输。支持 DSH **0.2.0-rc.2**；其他版本拒绝启动，不能仅凭协议号相同判为兼容。

| 依赖 | 实际验证与用途 |
| --- | --- |
| DSH | 已安装 macOS Desktop 内的 `runtime/cli/bin/dsh`，`--version` 为 `0.2.0-rc.2`；MIT |
| ACP | initialize `protocolVersion: 1`，agent `deepseek-harness-acp`；agentInfo 中 `0.0.1` 是协议组件版本，不是 CLI 版本 |
| Magpie | 已安装 `0.1.1293`，本机网关端口 3425；通过 `/api/hello` 验证身份，`/v1/models` 读取已配置路由 |
| 实际模型 | `codex/gpt-6-luna`，推理 `low`，由本机 Magpie 配置提供；没有修改全局模型或订阅 |
| MCP Swift SDK | 精确锁定 `0.12.1`，commit `a0ae212ebf6eab5f754c3129608bc5557637e605`，MIT；Server 与 StatelessHTTPServerTransport |
| 构建环境 | MacBook Pro / M5 Pro / 18 核 / 48 GB；macOS 26.6.2 (25G83)；Swift 6.4、macOS SDK 27；当次已验证宿主为 macOS 26；共享检出另有最低部署版本调整至 26 |

`~/.local/bin/dsh` 在这台机器上是指向旧 Tauri 目录的失效 shim。直接调用现有 `/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh` 可运行，且覆盖路径含空格及 GUI PATH 场景。Augma 优先检测当前桌面运行时，也支持用户填写完整路径；不改写旧 shim。

读取了已安装版本的实际 ACP、启动、profile、配置与 persistence 实现。上游检出 `22ddee3792402c3e70ec5f86a63c3e3e895a2f60` 的包版本为 `0.2.1-rc.3`，仅作公开文档参考，没有把它当作已安装版本测试。MCP SDK 0.11.0 曾在 Swift 6.4 下因 NetworkTransport 的并发捕获检查不能编译，改为已修复的 0.12.1 后构建及实际工具回路通过。

## 启动与配置归属

运行时使用独立 argv：`dsh --profile augma`；设置 Augma 专属 `DSH_HOME`，不通过 shell 拼接任务。版本探测 5 秒、ACP 普通请求 15 秒、模型任务 90 秒，退出先 SIGTERM，2 秒后仍存活才结束捕获的同一个 Process。只管理自己创建的进程。

| 数据 | 所有者与边界 |
| --- | --- |
| 后端、路径、模型、推理选项、测试指纹、启用状态 | Augma UserDefaults；检测/测试不提前启用业务发送 |
| 展示记录 | 窗口 NativeAssistantStore，最多四轮；不重放给 DSH |
| 模型上下文 | DSH Sessions，Augma 仅保存本次 App 生命周期内的 owner → session 映射 |
| 运行 profile | Augma 创建的临时私有目录；结束连接时删除 |
| 会话文件 | `~/Library/Application Support/Augma/Assistant/Sessions`；DSH 管理，可能包含问题、工具结果和回答 |
| 登录、订阅、模型来源 | Magpie；Augma 不读订阅 token，不复制凭据、不更改全局路由 |
| DeepSeek 兼容设置 | 原有开关与钥匙串；保留显式关闭和显式开启 |

隔离 profile 的 bundles 为空，仅挂载 timer、LLM、session、agent-loop、tools、system-prompt、retry、projection、JSONL persistence、token-meter、compaction、MCP resources、approval、pi-ai 和 ACP 启动所需的明确模块。没有 subprocess、bash、文件、网页、skills、subagent、settings、credentials 或插件管理模块。这是对所挂载能力的限制，不是 macOS 对外部 DSH 二进制的系统沙箱。

profile 的 provider 只有 Magpie，使用 Magpie 公开的应用归属标记 `magpie-augma`，不包含账户密钥。 通过本机 `magpie usage --csv --last 2h` 仅筛选 Augma 的归属字段，确认本轮 33 条请求记录为 `agent=augma`、`requested_model=codex/gpt-6-luna`、`swapped=false`；成功状态 200，取消状态 499。没有输出账户、密钥或会话列。模型由网关目录生成后，再经真实 ACP 会话返回的 `configOptions` 确认；不硬编码厂商列表。ACP option 的字符串是 opaque ID，必须原样回传，不能把 JSON 字符串重新编码后假设与原值相同。Magpie 的 `none` 映射为此 DSH 版本的 `off`，不支持的 `ultra` 不公布。

## ACP 能力矩阵

| 能力 | 已安装版本行为 | Augma 处理 / 证据 |
| --- | --- | --- |
| initialize | v1、HTTP MCP、close/list/resume | 验证 agent 名称、协议号与必需能力后才连通 |
| session/new | 返回 ID、模型和推理选项 | 每个窗口 / 业务 owner 独立 session |
| set_config_option | `model`、`reasoning_effort` select | 验证当前公布的值，错误不自动换路由 |
| session/prompt | 文本 prompt + end_turn | 当前系统要求和问题，不附 UI 历史 |
| session/update | 消息级文本、工具状态 | 有界累计回答；不宣称 provider token 流式输出 |
| request_permission | 双向 JSON-RPC | 原生允许一次 / 拒绝；夹具验证拒绝与取消后迟到允许 |
| session/cancel | notification | 立即撤销原生 scope，随后 close；迟到结果不写入新任务 |
| session/close | 请求 | 清理会话和 MCP listener；失败时回收对应旧进程 |
| session/resume | 恢复 DSH 上下文，不重放历史 | 实际进程重启后分别恢复两个独立 marker；无四轮重放 |
| MCP | HTTP transport 可用 | 官方 Swift SDK；真实 list/call/result 往返通过 |
| audio / 专属终端等扩展 | 首版不使用 | 语音先经系统 Speech 变文字；不提供任意终端能力 |

首次 HTTP 协议版本协商观察到客户端重试前的 400；实际 DSH 随后使用可接受版本完成 initialize、tools/list 和 tools/call。无状态 transport 的通知返回 202，GET 返回 405；不是 SSE 订阅服务。

## 工具与业务边界

| 工具 | 结果 / 限制 |
| --- | --- |
| `system_summary` | 真实采样时间、内存压力/压缩/swap、最多五个磁盘容量；不含磁盘名称和路径 |
| `application_usage` | 最多十个应用名称、近似 footprint、部分读取标记；不含 PID、文件路径或命令行 |
| `open_panel` | 仅 map/weather/notifications/settings/camera/browser；绑定当前窗口，单任务去重；不启动相机、不导航 URL |

输入和结果均有 schema；MCP 返回结构化数据和兼容文本。HTTP 仅监听 127.0.0.1，每会话随机令牌；拒绝错误 Host、Origin、重复头和 transfer encoding，限定请求体、连接数与 10 秒连接期限。令牌只在内存中，经 ACP 传给本次子进程，不写日志。

文字和语音 final 事件共用 NativeAssistantStore.submit，本地解析先于模型就绪检查。DSH 回答必须通过原有 JSON 校验且 command 为 null，打开面板只能由 MCP 的真实结果承担，避免再把回答当作第二次命令执行。DeepSeek 兼容调用和清理建议也经过统一运行时入口。

系统清理继续由 CleanupAdvice 生成匿名数字摘要并严格解析类别和本次应用编号；该会话没有 MCP scope，不会额外读取应用名称。模型建议不能选中文件、授权或执行清理。扫描和执行器没有在本 Goal 中重写。

## 证据矩阵

| 场景 | 验证方法与结论 |
| --- | --- |
| 真实工具循环 | 真实 DSH + Magpie：模型调用 system_summary、application_usage 后回答；测试断言两项均成功，原生 App 亦实际显示基于正常内存压力的建议 |
| 清理建议 | 真实模型接收合成匿名数值快照，返回可通过 CleanupAdvice.parse 的结构；不扫描、选择、删除用户文件 |
| 两会话恢复 | 实际会话分别记住 amber / silver，结束自有进程后 resume，各自回答正确；没有重放展示记录 |
| 实际取消 | 取消进行中的真实 prompt，结果不交付；下一次 session ID 改变且请求成功 |
| 协议失败 | Python 子进程夹具验证分片 Unicode、多帧、乱序、双向请求、异常 stdout、超限、超时、取消及崩溃 |
| 权限 | 完整 ACP 会话夹具触发原生 permission 状态，拒绝返回 reject_once；取消撤销待确认，迟到允许无效；受限真实工具回路没有触发额外权限请求 |
| 工具 HTTP | 实际 loopback listener + URLSession 验证缺失/错误/其他会话令牌、Origin 拒绝、结构化结果、撤销后拒绝；副作用用注入计数器 |
| DSH 缺失/失效/未知版本 | 可执行文件夹具逐项验证，显式路径失败不改用其他已安装入口 |
| Magpie 离线 | 停止本次测试自行启动的网关后，用独立 App 检测，准确提示网关不可用；没有修改登录或路由 |
| 鉴权/配额 | 远端错误分类夹具覆盖 401/429，不泄露原始错误；未使真实账户退出登录或耗尽额度来测试 |
| 配置迁移 | 新配置默认 DSH，旧 DeepSeek false/true 均保留；显式后端优先，迁移不写钥匙串 |
| 本地与语音 | 既有助手/Workspace 测试验证本地指令与语音 final 共用业务入口、取消及迟到事件；实际 App 离线仍能执行本地面板指令 |
| UI | 实际已签名 App 完成检测、模型选择、工具测试和单独启用；中/英/日界面和 AX 控件标签检查；键盘输入/提交/退出；420/540 pt、长路径、浅深色渲染 |
| 回收 | 实际闲置 60 秒自动释放 DSH；独立 App 仍运行；退出等待自有子进程结束；未结束用户原有 DSH/Magpie |

语音测试使用识别事件注入，未打开麦克风或录制用户语音。辅助功能验收检查了 VoiceOver 使用的 AX 树、名称与状态，没有让 VoiceOver 实际播报。未通过真实睡眠打断用户桌面，睡眠处理走与已验证 shutdown/cancel 相同的通知分支。未验证其他 Mac / Intel / macOS 27 或其他真实账户的额度失败。这些是明确的环境边界，不作为已完成的实机测试宣称。

## 检查命令与读数

项目要求的 SDK 链接参数不可省略：

```sh
swift test --package-path apps/mac \
  -Xswiftc -Xclang-linker -Xswiftc -isysroot \
  -Xswiftc -Xclang-linker -Xswiftc "$(xcrun --sdk macosx --show-sdk-path)"

# 明确消耗已配置模型额度，并读取系统摘要及应用名称/占用：
AUGMA_DSH_LIVE_TEST=1 swift test --package-path apps/mac \
  -Xswiftc -Xclang-linker -Xswiftc -isysroot \
  -Xswiftc -Xclang-linker -Xswiftc "$(xcrun --sdk macosx --show-sdk-path)" \
  --filter DSHLiveIntegrationTests

./script/build_and_run.sh --verify
node --test tests/release/*.test.mjs
```

- 完整 Swift 套件：345 项，7 项按环境跳过，0 失败。跳过项为两项 DSH live、Mole、Homebrew、Craft Hub、两项硬件读取；两项 DSH live 随后单独显式运行，均通过。
- 真实联调两项测试：31.285 秒；含工具回路、结构化清理建议、独立会话、恢复和取消。
- 发布脚本测试：19 项通过。`git diff --check` 通过。
- 仓库实际脚本构建、稳定本地签名、启动和主窗口校验通过。为避免与并行 App 走查互相干扰，另用相同构建产物及签名脚本制作独立 bundle ID / 可执行文件名的临时 QA App。最终 Swift 构建与此 QA App 均验证。

真实工具问答的单次读数（2026-10-26 22:13，本机调试构建）：

| 指标 | 数值与口径 |
| --- | --- |
| 运行时冷启动 | 0.942 秒，包含版本探测、Magpie 目录与 ACP initialize |
| prompt 后首个反馈 | 3.420 秒；ACP 消息/工具事件，不是 token 到达时间 |
| prompt 任务 | 6.658 秒 |
| 含启动和 session 配置总耗时 | 7.695 秒 |
| 子进程 post-task RSS / CPU | 170,064 KiB / 0.0%，`ps` 采样 |
| 忙碌采样峰值 | 170,496 KiB RSS / 49.4% CPU，0.5 秒采样，44 个进程样本；CPU 为 ps 口径，不是完整 profiler |
| 单独检测后的闲置 | DSH 145,696 KiB / 0.0%；QA App 151,136 KiB / 0.0% |
| 自动释放后 | DSH 不存在；QA App 135,280 KiB，仍可操作 |

另一次工具回路测得冷启动 0.705 秒、首反馈 3.504 秒、总耗时 8.187 秒。这些是单机样本，不是 SLA 或跨硬件基准。无请求时没有定时网络轮询；闲置释放是一次性 60 秒 Task，取消及配置变更会撤销它。

## 审阅与保留事项

新增代码集中于 `Assistant/Runtime/`、`AssistantRuntimeTests.swift` 与 MCP 依赖锁定。共享入口只增量接线；保留原生 UI、导航、快速记录、Market/Mole、清理、签名与发布等既有/并行改动。开始时保存了 HEAD `e77d9e585e4ef892ce8a705e0f4ac0196d1c35e7` 和脏文件基线。没有 reset、clean、stash、改分支、整包提交或发布。

首版不支持任意 DSH profile/provider、音频直传、逐 token UI、跨 App 重启恢复聊天窗口、后台长期常驻 agent 或自动 DSH 更新。会话 JSONL 由 DSH 保存在本机，不提交到仓库。最终审阅补丁按本 Goal 所属文件/增量生成，避免把共享检出中其他工作的内容归入本次交付。

## 主要来源

- [DSH ACP 文档（固定上游参考 commit）](https://github.com/deepseek-ai/deepseek-harness/blob/22ddee3792402c3e70ec5f86a63c3e3e895a2f60/packages/acp/acp/README.md)
- [DSH 架构](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md)
- [Magpie 应用集成](https://usemagpie.ai/docs/integrate)
- [MCP Swift SDK 0.12.1](https://github.com/modelcontextprotocol/swift-sdk/tree/0.12.1)
