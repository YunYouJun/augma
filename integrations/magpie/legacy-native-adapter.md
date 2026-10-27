> 历史记录：本方案已迁移为官方 Magpie 的独立插件。本机不再运行此构建，也不再应用以下源码补丁。当前安装与管理方法见 [README](README.md)。

# Magpie 应用列表适配

Augma 复用已安装的 DSH 0.2.0-rc.2 访问 Magpie。此 adapter 让 Magpie 的 Agent 页面显示 Augma，并直接管理模型、路由组和推理强度。Magpie 0.1.1673 的应用插件接口尚无独立 effort 字段，因此这里提供内置 adapter 补丁。

## 使用

1. 构建并运行包含 `AssistantMagpieConfiguration` 的 Augma，首次启动导出配置。
2. 运行包含此补丁的 Magpie，在 Agent 页面点击重新检测，找到 Augma。
3. 选择 Magpie 模型或路由组即接入；展开 Augma 卡片，在「新会话默认」中调整推理强度。
4. 回到 Augma「设置 → 助手」，检测连接，核对模型和强度，运行「测试模型与只读工具」，通过后启用助手。
5. 在 Magpie 点击「断开并还原」可恢复接入前的设置。模型或强度改变仍需重新测试。

本机联调最终选择 `group/augma`，路由组指向 `codex/gpt-6.1-terra`，推理强度 `medium`。这是本机选择，不是所有安装的固定模型；其他用户需要自己的已授权模型来源。

## 配置契约

路径：`~/Library/Application Support/Augma/Assistant/magpie.json`。

```json
{
  "version": 1,
  "runtime": "dsh",
  "model": "group/augma",
  "effort": "medium",
  "managed": true
}
```

- `version` 固定为 1；未知版本、错误类型、非法模型或强度均不覆盖原文件。
- `runtime` 为 `dsh` 或 `deepseek`。Magpie 接入时写入 `dsh`。
- `model` 是 Magpie 目录中的完整 ID，如 `group/augma`、`codex/gpt-6.1-terra`，不带 `magpie/` 前缀。未配置时可为空；受管理时必须非空。
- `effort` 为空表示默认。支持 `none`、`off`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`，界面仅提供所选模型和 DSH 能力的交集。
- `managed` 可省略，只有 `true` 表示由 Magpie 管理。未接入时 Augma 将自身设置写回此文件。

文件上限 64 KiB，保留未知字段。Magpie 第一次接入时保存原来的 `runtime/model/effort/managed` 四项，后续切换不覆盖该备份；断开只恢复这四项。原配置没有 `managed` 时恢复会移除它。备份缺失时报告错误，保留当前文件。

Augma 在激活、打开设置、检测连接和发起请求时读取配置，无轮询进程。配置变更会取消旧会话，撤销 DSH 启用状态和测试指纹。文件不保存网关密钥、账户、DSH 可执行路径、工具授权或启用状态，不能绕过 Augma 的测试与授权流程；网关地址继续由 Augma 的现有发现逻辑处理，DSH 桌面 profile 不受此 adapter 修改。

## 重建 Magpie

补丁基于官方 `v0.1.1673`，提交 `9fed5dc8c1093935cdfe2914f01dc1189c582f37`。在独立的 Magpie checkout 中应用；不要对已有修改的目录直接覆盖。

```sh
git clone --branch v0.1.1673 https://github.com/yetone/magpie.git magpie-augma
cd magpie-augma
git apply --check /path/to/augma/integrations/magpie/augma-agent-v0.1.1673.patch
git apply /path/to/augma/integrations/magpie/augma-agent-v0.1.1673.patch
git apply --check /path/to/augma/integrations/magpie/provider-logins-test-v0.1.1673.patch
git apply /path/to/augma/integrations/magpie/provider-logins-test-v0.1.1673.patch
make app VERSION=v0.1.1673-augma.5
```

按照 Magpie 仓库规范运行测试：使用隔离的临时 HOME，同时保留原有 Go 工具链缓存路径；不要让测试接触真实 Magpie/DSH 配置。针对本适配的测试为 `go test -tags nogui ./internal/agent -run '^TestAugma'`，完整检查见 Magpie 的 `docs/code-standards.md`。

第二个补丁仅修复该版本原有登录测试中的 synctest 隔离错误：测试通过只读目录阻止备份，不需要冻结时钟；跨虚拟时钟测试共享 `filememo.Written` 通道会导致运行时崩溃。补丁保留原文件未被覆盖及错误路径的断言，不修改生产登录逻辑，与 Augma adapter 单独保存。

macOS 安装前使用自己的稳定签名身份签名，验证 bundle，退出正在运行的 Magpie，并备份现有 `.app`。本次安装的 bundle ID 保持 `com.yetone.magpie`；Augma 自身仍使用原有签名身份。签名身份与账户凭据均不包含在补丁中。

本地源码构建不带官方发行签名。Magpie 自动更新会验证签名团队；本次实际观察到官方更新因团队不匹配被拒绝。这项验证应保留。若需要恢复官方更新，退出本地版并恢复原官方 bundle，或安装官方发行版；官方版在合入 adapter 前不会提供 Augma 卡片。升级到其他源码版本时需要重新应用或迁移补丁。

本次原官方 bundle 备份保存在 `~/Library/Application Support/Augma/Integration Backups/magpie-0.1.1673-original.app`。回退前先在本地适配版断开 Augma 管理，避免官方版不认识该卡片时无法从界面还原；Magpie 的供应商和账户配置保留在原位置。

## 实现与验收

Augma 端：`AssistantMagpieConfiguration.swift`、助手设置和 runtime 入口。Magpie 端：`internal/agent/augma.go`、注册表、图标和提示翻译。接入保留完整路由组 ID，断开恢复与非法配置拒绝有回归测试。

真实 UI 操作、请求记录和检查结果见[应用适配联调记录](../../docs/plans/2026-10-27-augma-magpie-adapter-validation.md)。
