# 无障碍（AX）自动化契约

日期：2026-11-05。状态：首版契约与契约测试已实现，用于对外部 Agent 暴露 UI 动作之前的准备工作。本文是 `scripts/generate-ax-contract.mjs`、`apps/mac/docs/ax-contract.json` 与 `apps/mac/Tests/AugmaDesktopDemoTests/AXContractTests.swift` 的说明。

## 这份契约解决什么

原生 macOS App 一直使用 SwiftUI 的 `.accessibilityIdentifier(...)`，但这些标识此前只是分散在源码里的字符串：验收时曾用原生无障碍树操作过运行中的 App（[disk-usage-acceptance.md](disk-usage-acceptance.md)），却没有一份稳定、版本化、机器可读的说明，也没有回归测试防止标识漂移。

首版把「源码里有哪些标识」收敛为契约，并明确每个标识的语义、可执行动作、读写属性、前置状态与幂等性。它是后续把 UI 动作暴露为 MCP 工具（方案 A）的前置条件：先有 interface，再暴露协议，避免写出第二份执行逻辑。

**当前没有对外的 MCP server。** 现有 [NativeMCPBridge.swift](../Sources/AugmaDesktopDemo/Assistant/Runtime/NativeMCPBridge.swift) 是每会话临时的 loopback 桥，只向 DSH 内置助手提供 `system_summary`、`application_usage`、`open_panel` 三个受限工具；外部 Agent 的本地 MCP 仍是待办。本契约不新增任何端口、进程或写权限。

## 文件

| 文件 | 角色 |
| --- | --- |
| [ax-contract.json](ax-contract.json) | 版本化的正式契约（`schemaVersion: 1`），消费者读取它 |
| [ax-identifiers.json](ax-identifiers.json) | 由源码生成的标识清单，含来源文件，便于交叉核对 |
| [generate-ax-contract.mjs](../../../scripts/generate-ax-contract.mjs) | 扫描 Swift 源码、生成清单、校验契约 |
| [AXContractTests.swift](../Tests/AugmaDesktopDemoTests/AXContractTests.swift) | Swift 侧的契约测试，独立复扫源码 |

## 契约字段

顶层：`schemaVersion`、`app`、`platform`、`identifierAttribute`（固定 `AXIdentifier`）、`description`、`reviewPolicy`、`scenes`、`roles`、`actions`、`accessLevels`、`runtimeVerification`、`elements`。

每个 `element`：

| 字段 | 含义 |
| --- | --- |
| `id` / `pattern` | 二选一。静态标识用 `id`；带动态后缀的用 `pattern`，占位符为 `{id}`，如 `project-select-{id}` |
| `role` | 期望的 AX 角色（`button`、`textField`、`popUpButton`、`progressIndicator`、`group` …） |
| `label` | 有 `.accessibilityLabel(...)` 时记录，否则为 `null` |
| `scene` | 所属窗口或面板，键必须在 `scenes` 里 |
| `actions` | 允许的动作：`press`、`setValue`、`readValue`、`select`、`focus` |
| `access` | `read` 或 `write`。含写动作的元素必须是 `write`；`read` 元素不允许写动作 |
| `preconditions` | 执行动作前必须满足的条件（如「助手不忙」「草稿非空」「用户在原生 UI 中确认」） |
| `disabledWhen` | 源码 `.disabled(...)` 里的条件表达式，若存在 |
| `idempotent` | 重复执行是否产生相同结果 |
| `reviewed` | **关键**。`true` 表示已对照 Swift 源码核对过全部字段，可作为 Agent 动作；`false` 表示由源码推导，仅保证可定位与读取 |
| `source` / `declaredVia` | 声明该标识的源码文件与方式（`.accessibilityIdentifier(...)`、`NativeOrbButton(identifier:)` 或 `ImmersiveDockView.identifier(for:)`） |
| `notes` | 边界说明；未复核条目带有统一的待复核提示 |

**条目数、场景数与复核进度以 [ax-contract.json](ax-contract.json) 为准**，本文不写死计数：契约由多个会话并行维护，硬编码数字会立刻过期。用 `node scripts/generate-ax-contract.mjs --queue` 可随时得到当前待复核清单与按风险排序的复核顺序。`reviewPolicy` 明确：**只有 `reviewed: true` 的条目可作为动作下发**；`reviewed: false` 的条目可用于按 id 定位和 `readValue`，但其 role、前置条件与副作用必须先在真实 App 中复核，不把推导结果宣称为已实测。

## 消费者如何使用

1. 读取 `ax-contract.json`，检查 `schemaVersion` 是否为 1。
2. 按 `scene` 缩小范围；用 `id` 精确匹配，或用 `pattern` 的 `{id}` 前后缀匹配具体标识（存在多个匹配时取最长字面前缀，例如 `immersive-dock-weather` 应解析为 `immersive-dock-{id}` 而不是 `immersive-{id}`）。
3. 执行动作前检查 `reviewed`、`access` 与 `preconditions`；`disabledWhen` 非空时先确认控件处于可用状态。
4. 通过 macOS 辅助功能 API（AXIdentifier / AXPress / AXSetValue 等）定位并操作；写操作沿用 App 已有的原生确认，模型不能自行生成批准。
5. 失败或取消时不宣称成功；`idempotent: false` 的动作不要因重试或会话恢复而重复执行。

## 生成与校验

```sh
node scripts/generate-ax-contract.mjs              # 校验（默认）
node scripts/generate-ax-contract.mjs --queue      # 按风险排序的待复核队列
node scripts/generate-ax-contract.mjs --bootstrap  # 从源码同步契约（合并，非破坏性）
node scripts/generate-ax-contract.mjs --write      # 刷新 ax-identifiers.json
swift test --package-path apps/mac --filter AXContractTests --disable-sandbox
```

生成器以 `apps/mac/Sources` 为唯一事实来源：提取 `.accessibilityIdentifier(...)` 的字面量、拼接前缀、`NativeOrbButton(identifier:)` 的字面量，以及 `identifier(for:)` 计算出的 Dock 模式；校验契约与清单一一对应、无重复、`source` 文件存在、枚举值合法、读写与动作一致。

**`--bootstrap` 是合并，不是重建。** 契约由多个会话并行维护：已有条目的 `scene`、`reviewed`、`notes`、前置条件与元素顺序全部原样保留；只在末尾追加源码中新出现的标识（推导为 `reviewed: false`），并移除源码中已消失的条目。顶层键与 `scenes` 顺序也保持不变；已同步时连文件都不重写。新标识出现在已有文件时，若该文件只有一个 scene 会继承它，否则回退到路径推断。

新增标识的流程：改源码 → `node scripts/generate-ax-contract.mjs --bootstrap`（先同步契约）→ `--write`（刷新清单）→ 在契约中补充语义、必要时把 `reviewed` 设为 `true` → 跑 Swift 测试。顺序不能反：`--write` 会先校验，契约里还没有新标识时会报错，这正是漂移检测在起作用。

`--queue` 只用契约已声明的字段分档（`read` → low；清理场景、需确认或带破坏性动作词 → high；其余写动作 → medium），输出复核顺序与「最小暴露工具集内的第一批候选」。它是**分诊提示，不是安全结论**：high 表示「先复核」，不等于「可安全暴露」。

暂未把生成器挂进 `pnpm check`：当前工作区有并行改动，先由 `swift test` 承担强制门禁；契约稳定后可在 `package.json` 增加一行 `ax:check`。

## 验证边界（不要超额宣称）

- **已实测**：运行中的原生 App 曾通过原生无障碍树完成存储分析的完整走查，见 [disk-usage-acceptance.md](disk-usage-acceptance.md)。
- **单元测不读实时 AX 树**。本机探测结果：`AXIsProcessTrusted()` 为 `false`，`AXUIElementCopyAttributeValue(..., kAXWindowsAttribute, ...)` 返回 `-25208`；即使创建 `NSApplication` 与真实 `NSWindow`，`NSHostingView.accessibilityChildren()` 仍为 0。因此 `swift test` 校验的是契约与源码一致性、按 id 定位与声明状态，不是实时 AX 属性。实时 AX 断言需要受信任的辅助功能进程与运行中的 App，属于验收流程。
- **VoiceOver 实际播报未验证**。此前仅检查过 VoiceOver 使用的 AX 树名称与状态（[2026-10-26-dsh-runtime-validation.md](../../../docs/plans/2026-10-26-dsh-runtime-validation.md)），本契约的 `runtimeVerification` 明确记录 `voiceOverAnnouncementVerified: false`，测试会阻止把它改写成 `true` 而无实测记录。
- 全局快捷键使用系统热键注册，不依赖辅助功能授权；不要用 AX 权限作为快捷键可用性的前提。
- 契约只覆盖原生 macOS App。VitePress 站点与 AR 演示是标准 ARIA 语义，没有运行时 MCP / AX 自动化接口。

## 与 MCP 方案 A 的衔接

若后续要让外部 Codex / Claude 等通过 MCP 操作 Augma，应把本契约当作工具清单的来源，按「薄适配器」实现：

- `tools/list` 由 `reviewed: true` 且 `access` 允许的元素生成，输入 schema 来自 `pattern` 占位符与 `preconditions`；
- `tools/call` 复用 [NativeToolScope](../Sources/AugmaDesktopDemo/Assistant/Runtime/NativeMCPBridge.swift) 的一窗口一任务 scope、取消同步撤销与 ACP 权限确认，不另写一份执行逻辑；
- 继续沿用现有安全边界：仅 loopback、每会话令牌、只读工具标注、清理/文件/授权不由模型生成批准；
- 不要把 `reviewed: false` 的推导条目自动暴露为写工具。

在此之前，外部 Agent 仍不能连接 Augma 的 UI 动作；本契约提供的是稳定、可回归的接口定义，而不是已开放的远程控制面。

## 后续待办

复核 `reviewed: false` 条目、只读 `ax_snapshot` 原型、接入 `pnpm check`、以及方案 A 的薄适配器 MCP server 均**尚未实施**，完成条件、最小工具集与分批顺序记录在 [2026-11-05-ax-contract-followups.md](../../../docs/plans/2026-11-05-ax-contract-followups.md)。
