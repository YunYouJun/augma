# AX 自动化契约：后续完善待办

日期：2026-11-05。状态：**待办，均未实施**。本文只记录后续工作与完成条件，不代表已完成或已验证。首版契约、生成器与契约测试已于同日交付，说明见 [ax-automation.md](../../apps/mac/docs/ax-automation.md)。

## 已交付（本次不重复实施）

- [x] 版本化机器可读契约 [ax-contract.json](../../apps/mac/docs/ax-contract.json)：`schemaVersion: 1`。**条目数、场景数与复核进度以文件为准**，不在计划里写死计数——契约由多个会话并行维护，硬编码数字会立刻过期。
- [x] 源码生成器 [generate-ax-contract.mjs](../../scripts/generate-ax-contract.mjs) 与清单 [ax-identifiers.json](../../apps/mac/docs/ax-identifiers.json)；`--bootstrap` 为**合并式同步**，保留手工复核的 scene、语义与元素顺序，已同步时不重写文件；`--queue` 输出按风险排序的复核队列。
- [x] 契约测试 [AXContractTests.swift](../../apps/mac/Tests/AugmaDesktopDemoTests/AXContractTests.swift)：9 个测试；全量 `swift test --package-path apps/mac --disable-sandbox` 为 500 测试、12 skipped、0 failures。
- [x] 验证边界文档化：单元测不读实时 AX 树、VoiceOver 播报未实测、当前无对外 MCP server。

## 待办（按建议顺序）

### P1：按风险分批复核 `reviewed: false`

**范围由目标倒推，不做全量逐条人工过。** 复核的目的是让某条能安全作为动作下发，所以先确定 P4 拟暴露的工具集，只复核那批；只读条目风险最低，保留 `reviewed: false` 也仍能定位与取值。

**最小暴露工具集 v1（建议）**：`main-window`、`panel:assistant`、`settings:assistant`、`panel:space`、`panel:browser`、`panel:project-regions`、`panel:storage-analysis` 七个场景里的低副作用写动作与配套读取。清理确认、移除、断开连接、退出沉浸等**不进 v1**。

- [ ] 先跑 `node scripts/generate-ax-contract.mjs --queue`，取「第一批建议」作为 v1 的待复核清单；high 档（清理场景、需原生确认、破坏性动作词）单独排在最前**复核**，但不进 v1 的**暴露**清单——两个顺序不要混为一谈。
- [ ] 按 scene 开批，一次一个面板；在真实 App 里核对 `role`、`label`、`preconditions`、`disabledWhen`、`idempotent` 与实际副作用。
- [ ] 复核结果落到 [generate-ax-contract.mjs](../../scripts/generate-ax-contract.mjs) 的 `CURATION` 覆盖层（或契约中直接维护；`--bootstrap` 现在会原样保留，不会覆盖并行维护）。
- [ ] **真实 App 里当下验证不了的**（需特定设备、状态或外部账号）保留 `reviewed: false` 并在 `notes` 写明原因，不为凑数标 `true`。
- [ ] 每批后跑 `node scripts/generate-ax-contract.mjs`、`node scripts/generate-ax-contract.mjs --queue`（确认队列缩短）与 `swift test --package-path apps/mac --filter AXContractTests --disable-sandbox`。

**完成条件**：v1 清单内不再有推导语义；可作为动作下发的条数有明确记录且都由真实 App 走查支撑；未复核条目仍仅限定位与 `readValue`。

### P2：只读 `ax_snapshot` 原型

- [ ] 在现有 [NativeMCPBridge.swift](../../apps/mac/Sources/AugmaDesktopDemo/Assistant/Runtime/NativeMCPBridge.swift) 的受限工具桥上增加一个只读快照工具，返回当前窗口/场景的可见标识与状态；不新增写动作。
- [ ] 沿用 `NativeToolScope` 的一窗口一任务 scope、取消同步撤销、schema 与 `readOnlyHint`；不新开常驻端口。
- [ ] 补工具级测试：结构化结果、令牌/Host/Origin 拒绝、撤销后拒绝、超时边界。

**完成条件**：工具能返回真实数据且拒绝/取消无副作用；仍不宣称外部 Agent 可连接。

### P3：接入持续检查

- [ ] 在 `package.json` 增加 `ax:check`（`node scripts/generate-ax-contract.mjs`），并挂进 `check` 链；当前工作区有并行改动，先由 `swift test` 承担门禁。
- [ ] 确认 `pnpm check` 全链路通过，且新增 `.accessibilityIdentifier` 会让检查失败并给出更新契约的提示。

**完成条件**：契约漂移在 CI/本地检查中被强制拦截，而不只依赖人记得跑命令。

### P4：方案 A —— 对外薄适配器 MCP server

- [ ] 前置条件：P1 的**最小暴露工具集 v1** 全部复核完、P2 验证过只读回路、用户明确需要外部 Agent 连接。
- [ ] `tools/list` 只由 v1 内 `reviewed: true` 且 `access` 允许的元素生成，不一次性把整份契约翻成工具；`tools/call` 复用 `NativeToolScope` 的 scope、ACP 权限确认与取消，不另写执行逻辑。
- [ ] 保持安全边界：仅 loopback、每会话令牌、清理/文件/授权不由模型生成批准、不把 `reviewed: false` 自动暴露为写工具。
- [ ] 补真实外部 Agent 联调证据与性能/权限/取消验收，按仓库既有验收文档格式记录。

**完成条件**：有真实往返证据且不超额宣称；在此之前外部 Agent 仍不能操作 Augma 的 UI 动作。

## 明确不做的边界

- 不把 `reviewed: false` 的推导条目自动升级为可写工具；`--queue` 的 high 档只是「先复核」，不是「可安全暴露」。
- 不用 `--bootstrap` 从零重建契约（会丢失并行会话的手工复核）；只做合并式同步。
- 不新开常驻监听端口或第二份执行逻辑；不因本待办重写扫描、清理与布局模块。
- 不把单元测改成读取实时 AX 树：需要受信任的辅助功能进程与运行中的 App，属于验收流程。
- 站点与 AR 演示无运行时 MCP / AX 自动化接口，本待办只覆盖原生 macOS App。

## 参考

- [ax-automation.md](../../apps/mac/docs/ax-automation.md)：契约字段、消费流程与验证边界
- [disk-usage-acceptance.md](../../apps/mac/docs/disk-usage-acceptance.md)：原生 AX 树操作实测证据
- [2026-10-26-dsh-runtime-validation.md](2026-10-26-dsh-runtime-validation.md)：MCP 工具边界与 VoiceOver 未实测记录
- [2026-10-26-cleanup-plugins.md](2026-10-26-cleanup-plugins.md)：「同一个 interface 再暴露为本地 MCP」的原始设计约定
