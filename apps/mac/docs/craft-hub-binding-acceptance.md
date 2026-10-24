# Craft Hub 可选项目绑定验收

2026-10-25，在 Apple Silicon、macOS 26.6.2 上验证。

## 实现边界

- Craft Hub 提供明确共享的项目名称、目录、信任状态、命令／技能摘要及可选 Git 引用。
- Augma 保存区域布局、工作网址、应用选择，以及可随时解除的项目引用。
- 使用现有可撤销只读授权；连接不执行项目命令、不授予信任、不启动 JSON 中的 MCP 命令。
- 断开或撤销后保留区域；已绑定区域需要重新连接或主动解除绑定。独立区域继续使用本地配置。
- 原生项目区域是本次入口，浏览器版 Augma 不读取本机授权文件。

## 已验证

| 验证 | 结果 |
| --- | --- |
| `swift test --package-path apps/mac` | 240 项，239 通过；真实宿主测试默认跳过，另行运行通过 |
| `node script/verify-craft-hub.mjs /absolute/path/to/craft-hub` | 真实原生门禁、HTTP 客户端和共享范围通过；未运行命令或改变信任 |
| `./script/build_and_run.sh --package` | arm64 / x86_64 Release 构建及通用 App 打包通过 |
| Release 窗口走查 | 粘贴连接、只显示共享项目、选择添加、摘要与三维名称展示、解除绑定和主动断开通过 |
| 本地数据与异常测试 | v1 迁移、绑定重载、原配置恢复、改名／移动目录、撤销、不同授权源、迟到／乱序响应通过 |
| Craft Hub 配套验证 | lint、typecheck、完整测试、build、public-boundary、macOS lint、121 项原生测试、原生 Release 构建与实际启动通过 |

UI 走查使用独立 App 标识与数据目录、临时共享项目和临时授权。脚本用 `finally` 与信号处理清理测试宿主，按 PID、启动时间和可执行文件核实退出；日常使用中的 Craft Hub 保持运行。测试配置与记录保留在本机临时目录，未替换日常安装。

## 尚未覆盖

- macOS 15 最低系统及 Intel 真机启动；通用构建通过不等于已在这两类环境运行。
- 长期日常使用验收。
- Developer ID 签名、公证及正式发布凭据；本次使用本地 ad-hoc 签名。

操作方式和数据存储见 [原生应用说明](../README.md#可选连接-craft-hub)。
