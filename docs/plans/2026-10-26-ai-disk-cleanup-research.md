# AI 磁盘清理：可复用方案调研

日期：2026-10-26。状态：资料调研记录；后续 Homebrew 接入与真实验收、整机原生实现决策见[实施计划](./2026-10-26-ai-disk-cleanup.md)。初始调研阶段仅查阅官方文档、仓库源码和许可证，未安装工具、扫描真实用户目录或执行清理。上游 `main` / `master` 是浮动分支，接入时须重新选择并固定发布版本。

## 建议

保留 Augma 原生扫描、候选验证和废纸篓执行链路。开发工具的缓存交给对应工具管理；重复文件算法可以复用 Czkawka；Lemon Cleaner 和 Mole 更适合研究产品分类和工程边界。AI 消费经过整理的候选摘要，负责排序、解释和生成待确认方案。

以下“采用建议”是针对 Augma 的工程判断，不代表上游承诺了稳定 SDK、JSON schema 或可恢复删除。

## 开源项目

| 方案 | 已核实能力与许可 | Augma 采用建议 |
| --- | --- | --- |
| Tencent Lemon Cleaner | 官方 README 列出大文件、重复文件、空间分析与实际清理等独立模块。LemonDaemon 使用 GPL v2，Monitor / Cleaner 使用 GPL v3，第三方组件另列。 | 参考场景分类、应用专用规则和扫描/操作分层。暂不把整套实现嵌入应用；这不是现成 SwiftPM 清理 SDK。复制、链接或捆绑前，需单独核实许可与分发要求。 |
| Czkawka | 官方提供 Rust core 和 CLI，可扫描重复文件、大文件等；core / CLI 的 Cargo 元数据均标为 MIT。CLI 支持扫描范围、排除目录、线程限制及 JSON 文件输出。 | 后期优先评估为可选重复文件扫描引擎。让它提供候选，Augma 自己验证并执行用户选定的操作。首期安装包与构建缓存无需引入 Rust 工具链。 |
| Mole | 官方支持安装包、构建产物清理、占用分析和 dry-run；当前 `LICENSE` 为 GPL-3.0。README 明确区分废纸篓与永久删除，`clean` / `purge` / `installer` 属于永久删除。 | 可参考规则组织、忽略清单和不完整扫描的表达。可用其 JSON 占用报告做隔离评估；不把通用 `mo clean` 包装为 Augma 的默认清理按钮。 |

Lemon 的模块与许可依据：[README](https://github.com/Tencent/lemon-cleaner/blob/master/README.md)、[Cleaner / Monitor 许可证](https://github.com/Tencent/lemon-cleaner/blob/master/LICENSE.txt)、[Daemon 许可证](https://github.com/Tencent/lemon-cleaner/blob/master/LICENSE_LemonCleaner_LemonDaemon.txt)。[Podfile](https://github.com/Tencent/lemon-cleaner/blob/master/Podfile) 展示 Xcode 工程、CocoaPods 和多个本地模块的集成方式；因此直接移植到当前 SwiftPM 工程需要适配。Augma 自身的许可见 [LICENSE](../../LICENSE)。

Czkawka 的能力依据：[项目 README](https://github.com/qarmin/czkawka)、[CLI 官方说明](https://github.com/qarmin/czkawka/blob/master/instructions/Instruction_CLI.md)。许可依据：[core Cargo.toml](https://github.com/qarmin/czkawka/blob/master/czkawka_core/Cargo.toml)、[CLI Cargo.toml](https://github.com/qarmin/czkawka/blob/master/czkawka_cli/Cargo.toml)。分发时仍需逐项检查选定版本的传递依赖和资源许可。

Mole 的能力与删除语义依据：[README 的 Run、Safety 与 Analyze 部分](https://github.com/tw93/Mole#safety)，许可见 [LICENSE](https://github.com/tw93/Mole/blob/main/LICENSE)。`mo analyze --json` 的文档区分 `complete`、`partial`、`unavailable`；退出成功不等于扫描完整。它的完整性也只覆盖既定排除规则内的扫描范围。

### Mole 的价格与版本区别

官网当前列出的原生 Mac 应用价格为一次性 19 美元；FAQ 明确命令行版仍免费开源。收费的桌面应用和 GPL-3.0 的 CLI 需要分别判断，不能把“桌面版收费”理解为“调用 CLI 需要购买”。来源：[Mole 官网价格与 FAQ](https://mole.fit/#faq)。官网的 AI Cleanup 页面主要介绍 AI 工具缓存、历史会话与工作区的整理，不能据此认定它已经提供可直接嵌入 Augma 的大模型决策 SDK。

Augma 本轮选择参考功能设计并原生独立实现：占用概览、分类预览、保护名单与操作回执。保持既有 MIT 代码路线，不复制或翻译 GPL 实现和整套规则库；具体扫描与清理规则依据系统和来源工具的官方资料逐项验证。

## 开发工具接口

这些接口可以组成独立 provider，但不是通用的“枚举文件后逐项移入废纸篓”协议。工具原生清理可能立即删除数据，界面必须明确它与废纸篓操作的区别。

| 工具 | 可复用接口 | 接入边界 |
| --- | --- | --- |
| Homebrew | `brew cleanup --dry-run` 预览旧版本、过期下载等清理项目；`brew autoremove --dry-run` 预览不再需要的依赖。 | 两种动作分别展示；autoremove 涉及卸载，不能混为下载缓存。官方手册未在这两项下承诺 JSON 输出，需固定版本、解析样例与降级展示。不要把其结果直接转换成通用文件删除操作。 |
| Docker | `docker system df --format json` 提供守护进程占用摘要；各类 prune 交给 Docker 管理。 | 第一步只做占用诊断。`system prune` 范围包含停止的容器、网络、镜像与构建缓存；默认动作不应扩到数据卷。构建缓存可单独评估 builder prune。当前文档未提供通用 prune dry-run，不要宣称能预览并锁定同一批对象。 |
| pnpm | `pnpm store prune` 由 pnpm 清理 store 中未被引用的包。 | 只在用户选择该工具操作时调用；后续安装可能重新下载。该页没有提供等价 dry-run，整个 store 目录大小也不是本次可释放量。不要自己逐文件裁剪 store。 |
| uv | `uv cache prune` 清理未使用缓存；`uv cache clean` 为更广范围的清空。 | 官方明确不应直接修改缓存目录。遵守 uv 自身锁机制，首期不开放 `--force`。`--ci` 是专门面向 CI 的策略，不当作桌面默认；不能虚构 dry-run 或事前精确回收量。 |

Homebrew 语义依据：[cleanup](https://docs.brew.sh/Manpage#cleanup-options-formulacask-)、[autoremove](https://docs.brew.sh/Manpage#autoremove---dry-run)。预览与执行之间状态仍可变化，接入前应重新检查工具版本和运行状态，并让原工具处理自身元数据。

Docker 语义依据：[system df](https://docs.docker.com/reference/cli/docker/system/df/)、[system prune](https://docs.docker.com/reference/cli/docker/system/prune/)、[官方清理指南](https://docs.docker.com/engine/manage-resources/pruning/)。JSON 统计属于 Docker daemon 口径，不能直接当作 macOS 宿主卷新增可用空间。

pnpm 语义依据：[store 官方文档](https://pnpm.io/cli/store)。uv 语义依据：[Cache safety / Clearing the cache](https://docs.astral.sh/uv/concepts/cache/#cache-safety)；uv 文档还指出硬链接和 copy-on-write 会影响空间估算，并提供单独的物理空间估算预览功能，因此候选大小与实际释放量需要分别记录。

## Czkawka 接入前验证项

- 固定正式发布版本与构建哈希，确认该版本确有需要的子命令和 JSON 参数。当前 master 文档列出 `-C` 紧凑 JSON、`-p` 格式化 JSON，并说明 macOS 预编译版本支持情况；这不是对所有历史安装版本的承诺。[官方说明](https://github.com/qarmin/czkawka/blob/master/instructions/Instruction_CLI.md)
- 保持默认的结果模式，不允许上游删除、硬链接替换或 EXIF 修改参数进入调用器。使用固定可执行文件和参数数组；扫描范围由用户选择；需要时禁用工具本地扫描缓存。JSON 参数也可在 [CLI 源码](https://github.com/qarmin/czkawka/blob/master/czkawka_cli/src/commands.rs) 核对。
- 为固定版本建立 JSON fixture，验证退出码：文档中的 `11` 表示找到结果，不能一概视作运行失败。保留警告，取消时终止子进程；结果文件写到应用专用临时目录，结束后移除。
- 独立验证 Apple Silicon / Intel 构建、签名、公证、打包大小、子进程权限和用户所选目录授权；文档中的平台支持不替代实际发行验证。
- 重复内容只证明内容相同，不能决定哪个业务副本可以删除。先完整扫描并校验，保留组内至少一份；执行前由 Augma 重新验证文件身份、修改状态与路径范围。

## 尚未完成的验证

初始资料调研没有在本机安装或试运行这些第三方工具；后续已完成的 Homebrew 验证见实施计划，其余工具仍未完成具体版本的输出 schema、性能、TCC 交互、硬链接 / APFS clone 行为及可恢复性验证。上面的候选接口不能一概表述为“已经接入”或“保证能释放指定容量”。后续优先交付原生只读占用概览与清理结果核对，再按收益增加来源。
