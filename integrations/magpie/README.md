# Augma 的 Magpie 插件

使用官方 Magpie 的 `magpie.agent`、`magpie.panels` 和 `magpie.middleware` 扩展点，无需修改、重编译或重新签名 Magpie。插件源码位于 [`magpie-plugin-augma`](magpie-plugin-augma)。本机已验证官方 **0.1.1673**、本机 **DSH 0.2.0-rc.2** 和包含配置同步功能的 Augma。

## 管理入口

- **模型/路由组**：Magpie → Agent → Augma 卡片的原生模型选择器。
- **推理强度**：Agent 页面底部「Augma 推理强度」面板。选择后点击「保存」，不增加独立导航 tab。支持 Low、Medium、High、XHigh、Max；选用当前模型支持的值，Augma 检测会核对 DSH 公布的能力。
- **应用与验证**：返回 Augma → 设置 → 助手 → 检测连接与模型 → 测试模型与只读工具 → 启用 DSH 助手。模型或强度改变会撤销旧测试状态，不能继续使用旧会话。

本机最终设置是 `group/augma` → `codex/gpt-6.1-terra`，推理强度 **Medium**。更换来源模型时，编辑 Magpie 的 Augma 路由组即可继续保留专属用量归属。

## 本地安装

先启动支持此集成的 Augma，生成 `~/Library/Application Support/Augma/Assistant/magpie.json`。使用官方 Magpie 0.1.1673 或兼容上述插件接口的版本。以下命令在 Augma 仓库根目录运行：

```sh
ditto integrations/magpie/magpie-plugin-augma "$HOME/Library/Application Support/Augma/Integrations/magpie-plugin-augma"
/Applications/magpie.app/Contents/MacOS/magpie plugin add "$HOME/Library/Application Support/Augma/Integrations/magpie-plugin-augma"
/Applications/magpie.app/Contents/MacOS/magpie plugin options "$HOME/Library/Application Support/Augma/Integrations/magpie-plugin-augma" '{"integration":"augma-v1","effort":"medium"}'
```

第三条命令设置初始 Medium；更新插件时保留现有 options。也可首次在插件面板点击保存，初始化同步标记。插件为本地包，不依赖 Node/Bun 常驻进程、额外守护进程或网络权限，不复制账户凭据。

在 Magpie 点击重新检测，直接在 Augma 卡片选择目标路由组。已有本机路由可通过 CLI 连接：

```sh
/Applications/magpie.app/Contents/MacOS/magpie augma magpie/group/augma
```

本机目标路由已经存在，安装不重新创建或覆盖其他路由、供应商及 DSH 桌面配置。新机器需要先在 Magpie 配置自己的已授权模型来源和 Augma 路由组。

## 配置与同步

Agent 插件仅管理 Augma 配置文件的 `version/runtime/model/managed/plugin`，完整保留 `group/`、`codex/` 前缀。Magpie 保存这些键原来的值，用于「断开并还原」。`effort` 留作断开后的原配置，不会被目录刷新覆盖。

```json
{
  "version": 1,
  "runtime": "dsh",
  "model": "group/augma",
  "effort": "medium",
  "managed": true,
  "plugin": "magpie-plugin-augma"
}
```

插件面板使用官方 `magpie.options.get/set` 保存自己的设置：

```json
{ "integration": "augma-v1", "effort": "medium" }
```

Augma 在激活、打开设置、检测及请求前读取配置；受插件管理时，从 Magpie 的 `~/.config/magpie/plugins.json` 中读取唯一启用且带 `integration: augma-v1` 标记的条目。若 Augma 使用绝对路径的 `XDG_CONFIG_HOME`，则读取其 `magpie/plugins.json`，应与 Magpie 保持一致。不支持自动发现 Magpie portable 数据目录。

Augma 只解码此同步所需的字段，不写 Magpie 插件列表，不导入供应商、密钥或会话配置。文件缺失、插件关闭、重复标记、非法值会撤销旧测试并阻止发送；修复后重新检测。原配置保留未知键，版本和类型错误不会被 Augma 覆盖。

网关 middleware 仅对 `ctx.agent === "augma"` 的 Chat/Responses 请求设置推理强度，保留消息、工具、路由模型及其他 reasoning 字段。其他应用原样通过。Magpie 的 JS middleware 框架发生运行错误时会按官方规则放行原请求，因此 Augma 自身也同步同一强度并在发送前校验；此 middleware 不承担鉴权职责。

## 断开、卸载与官方包恢复

先在 Augma 卡片选择「断开并还原」，或执行：

```sh
/Applications/magpie.app/Contents/MacOS/magpie augma default
/Applications/magpie.app/Contents/MacOS/magpie plugin rm "$HOME/Library/Application Support/Augma/Integrations/magpie-plugin-augma"
```

断开恢复接入前的配置，插件 options 不会写进 Augma 的本地原配置。之后 Augma 可自行管理模型和强度。先关闭/移除插件而未断开时，Augma 会提示配置异常；重新启用插件再断开即可。

从旧内置 adapter 迁移时：先用旧版 Magpie 断开 Augma，退出 Magpie，再恢复原官方 `.app`，验证签名，然后按上面的步骤安装插件。不覆盖 Magpie 的账户、供应商和路由数据，不跳过官方签名检查。

本机已恢复 `/Applications/magpie.app`，官方 Team ID 为 `LY7MVTUDZG`。官方原包和退出使用的自定义包保存在 `~/Library/Application Support/Augma/Integration Backups/`。旧内置 adapter 的源码补丁只保留在本地迁移存档中，不属于此插件安装或构建依赖。

## 验证

```sh
node --test integrations/magpie/magpie-plugin-augma/test/*.test.js
./script/build_and_run.sh --verify
```

Swift 配置同步回归覆盖模型/强度变更、重新测试、断开恢复、非法/缺失/关闭/重复插件配置。已在官方 Magpie 的真实窗口完成模型切换、Low → Medium 保存和 Augma 工具/普通对话联调。验证记录见 [插件迁移联调](../../docs/plans/2026-10-27-augma-magpie-plugin-validation.md)。
