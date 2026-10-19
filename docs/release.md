# 0.2 发布与域名迁移

站点分别部署到 EdgeOne Pages 与 Cloudflare Pages；npm 包发布和旧站迁移分别处理。公开安装命令依赖 0.2.0 包发布。

## 本地与 CI

使用 Node 24、package.json 固定的 pnpm 版本，执行：

```sh
pnpm install --frozen-lockfile
pnpm exec playwright install chromium firefox webkit
pnpm check
pnpm preview
```

`pnpm check` 覆盖生成校验、lint、类型、组件与资源生命周期、主站与 AR 构建、npm 消费、真实 Registry CLI 安装及三个浏览器。站点产物为 `apps/site/.vitepress/dist`，其中包含独立 AR 构建的 `/ar/`。

`pnpm-workspace.yaml` 保留 `trustPolicy: no-downgrade`。四个精确版本例外用于旧维护分支：semver 6.3.1、chokidar 4.0.3、undici-types 6.21.0 的 npm integrity 与重构前锁文件一致；Vite 5.4.21 是 VitePress 1 的兼容依赖，具有 provenance，但不同于新主版本的 OIDC 发布。升级时重新审查并删除失效例外。参考 [pnpm 跨维护分支的讨论](https://github.com/orgs/pnpm/discussions/11084)。

## 分支与发布顺序

- `main` 是唯一的长期分支，也是默认分支和 Cloudflare Pages 的生产分支，推送即部署。功能分支通过 PR 合入 `main`；CI 覆盖 `main` 的 push 与所有 PR。2026-10-19 起不再使用 `dev`。
- 正式发布由 `v*` 标签触发：在 `main` 上运行 `pnpm release`（bumpp）更新版本、提交 `chore: release vX.Y.Z`、打标签并推送。先发布 Core，再发布 Vue，然后验证公开安装。
- 0.2 站点已于 2026-10-19 先于 npm 发布上线：在 `0.2.0` 发布之前，站点上的 `pnpm add augma` 会安装 API 不兼容的 0.1.1，Registry 条目依赖的 `@augma/core@0.2.0` 也无法安装。应尽快完成 npm 发布。
- 合并生产分支时保留发布提交历史，不使用 squash / rebase 改写已打标签的提交。EdgeOne 使用该发布工作流保存的站点 artifact，两个站点保持相同内容。

## 准备产物（不发布）

在干净、已提交的工作区执行：

```sh
pnpm check
pnpm release:pack
pnpm release:verify
```

`release-artifacts/` 包含两个 `.tgz` 和 `manifest.json`。清单记录版本、完整 Git 提交 SHA、固定包名与 SHA-512 integrity；目录被 Git 忽略。验证拒绝不同提交、修改过的 tarball、缺失包或额外文件。`release:pack` 只打包，必须先成功执行 `pnpm check`，不会发布或创建版本标签。

GitHub Actions 的 **Prepare or publish packages**（`release.yml`）在推送 `v*` 标签时自动准备并发布；手动运行默认 `publish=false`，可在 `main` 或功能分支演练。它完成检查后保存包与站点 artifact，名称包含提交 SHA、运行 ID 与尝试次数。准备任务不使用 npm environment 或写权限。

## npm 正式发布

目标版本为 `0.2.0`。版本号写在 5 个文件里：根目录、Core、Vue 的 package.json，`scripts/catalog.mjs` 和 `packages/augma/src/index.ts`。`bump.config.ts` 列出全部 5 个文件，`pnpm release` 会一起更新；不一致时 `pnpm generate` 与 `check-release` 报错。变更说明维护在 [CHANGELOG](../CHANGELOG.md)，bumpp 不会修改它。

发布使用 npm Trusted Publishing（OIDC），仓库不保存 npm token。发布任务申请 `id-token: write`，绑定 GitHub environment `npm`（只允许 `v*` 标签部署），要求 npm CLI 不低于 11.5.1，并附带 provenance。[npm 官方 trusted publishing 文档](https://docs.npmjs.com/trusted-publishers/) 要求在包设置中配置仓库、工作流与 environment；仓库工作流文件本身不能代替 npm 端授权。

`scripts/publish-artifacts.mjs` 在发布任何包之前，逐个查询 registry 上的同版本：

- 不存在：按 Core → Vue 顺序发布本次验证过的 tarball。
- 已存在且 integrity 与清单一致：跳过。用于重跑失败的任务，或某个包已手动首发。
- 已存在但 integrity 不同：在发布任何包之前报错。不能覆盖 npm 上已存在的版本，核查来源后改用新版本号。

### 首次发布 0.2.0

`augma` 已在 npm 上（0.1.1），`@augma/core` 尚未注册。npm 通常只能为已存在的包配置 trusted publisher，所以 Core 的第一个版本由维护者手动发布，并且必须使用工作流打出的同一个 tarball：在本机重新打包可能改变压缩字节和 integrity，工作流就会拒绝跳过。若届时 npm 已支持为未注册的包预先配置 trusted publisher，直接给两个包配置后运行一次即可，跳过第 4–6 步。

1. 在 npm 创建 `augma` 组织（提供 `@augma` scope），确认自己是 `augma` 包的维护者。用 `npm whoami --registry=https://registry.npmjs.org` 验证登录；不要把 token 或验证码写入仓库。
2. 在 npmjs.com 的 `augma` 包设置中添加 Trusted Publisher：GitHub Actions，owner `YunYouJun`，仓库 `augma`，工作流 `release.yml`，environment `npm`。
3. 版本号已是 0.2.0，不需要 bumpp：在通过检查的 `main` 提交上执行 `git tag v0.2.0 && git push origin v0.2.0`。标签推送会自动运行 **Prepare or publish packages**。准备任务通过后，发布任务会因 Core 尚无授权而失败；Core 排在第一位，此时不会发布任何包。
4. 把这次运行的 `augma-packages-…` artifact 下载到该标签 checkout 的 `release-artifacts/`，运行 `pnpm release:verify`，再在本地登录后只发布 Core：`npm publish release-artifacts/augma-core-0.2.0.tgz --access public --registry=https://registry.npmjs.org`。这次手动发布不带 provenance。
5. 等 `npm view @augma/core@0.2.0 dist.integrity --registry=https://registry.npmjs.org` 返回与 `manifest.json` 相同的值，再为 `@augma/core` 添加同样的 Trusted Publisher。
6. 回到第 3 步那次运行，选择 **Re-run failed jobs**（不要选 Re-run all jobs，以免重新打包）。发布任务复用同一个 artifact，跳过 Core，通过 OIDC 发布 `augma` 并附带 provenance，然后自动核对公开版本、`latest` 和 integrity。
7. 在干净目录用官方 registry 安装 `augma@0.2.0`、构建最小 Vue 项目，再用正式域名执行 Registry 安装验证。只有此时才能宣布公开安装可用。

### 之后的版本

两个包都配置好 trusted publisher 后：

1. 把本次变更写进 CHANGELOG 并提交到 `main`，在本地运行 `pnpm check`。
2. 在 `main` 上运行 `pnpm release` 并选择版本号。bumpp 更新 5 个版本文件，提交 `chore: release vX.Y.Z`，创建同名标签并推送。
3. 标签推送自动触发发布工作流：完整检查、打包，再通过 OIDC 依次发布 Core 和 Vue，最后核对公开版本。失败时对同一次运行选择 **Re-run failed jobs**，已发布且一致的包会被跳过。

手动运行工作流且保持 `publish=false` 时只检查和打包，可以随时演练。

### 部分发布失败

npm 发布没有跨包事务。Core 已发布而 Vue 失败时，对同一次运行选择 **Re-run failed jobs**：发布任务跳过 integrity 一致的 Core，只发布 Vue。

工作流不可用时的手动恢复：

1. 把该次运行的 artifact 下载到对应提交的 `release-artifacts/`，运行 `pnpm release:verify`，并用 `npm view <包名>@0.2.0 dist.integrity --registry=https://registry.npmjs.org` 确认已发布的包与清单一致。
2. 在本地登录后只发布尚未发布的 tarball，例如 `npm publish release-artifacts/augma-0.2.0.tgz --access public --registry=https://registry.npmjs.org`。本地发布不带 provenance。
3. 运行 `pnpm release:check-published`，再继续公网验收。

## macOS 客户端

发布工作流的 `mac` 任务在 `macos-26` runner 上运行 `swift test` 和 `pnpm mac:package`，生成 Apple 芯片与 Intel 通用的 `Augma-macOS.zip` 及其 `.sha256`，保存为 `augma-macos-…` artifact。推送 `v*` 标签（或在匹配标签上手动 `publish=true`）时，`github-release` 任务在准备任务与 `mac` 任务都通过后，把两个文件附加到同名 GitHub Release：Release 不存在就创建并生成说明，已存在则覆盖同名文件。它不依赖 npm 发布任务，首次发布时 npm 失败也会照常上传。

站点 `/guide/macos` 与首页 AR 演示区链接 `releases/latest/download/Augma-macOS.zip`，因此文件名固定、不带版本号；第一个带安装包的 Release 发布之前，该链接返回 404。安装包只有 ad-hoc 签名，首次打开需要在「系统设置 → 隐私与安全性」中确认。改用 Developer ID 签名与公证需要 Apple Developer Program 账号，并把证书和 App Store Connect API 密钥配置为仓库 secrets。

## 主域名与站点

主站是 `https://augma.yunyoujun.cn`，文档、展示、AI 静态入口和 `/ar/` 一起部署。

- EdgeOne Pages 项目 `augma`（`makers-qvfxx56v4tcl`）使用海外加速区，生产环境部署 `apps/site/.vitepress/dist`。
- 代码推送到 `main` 后，CI 验证并保存站点 artifact；生产部署使用该发布工作流的站点 artifact，或在对应干净提交上重新验证的构建：

  ```sh
  pnpm check
  edgeone pages deploy apps/site/.vitepress/dist -n augma -e production -a overseas
  ```

- `augma.yunyoujun.cn` 在 EdgeOne Pages 项目中绑定到 Production。Cloudflare DNS 配置两条 DNS-only CNAME：`augma.yunyoujun.cn → augma.yunyoujun.cn.pages.dnsoe5.com` 用于站点访问，`_dnsauth.augma.yunyoujun.cn → augma.yunyoujun.cn.eoacme0.com` 用于免费 HTTPS 证书验证和续期。核对 HTTPS 证书和公网访问。
- canonical、sitemap、Skill 与生成索引均采用主域。域名绑定与 DNS 配置需在托管平台完成。

## Cloudflare Pages 域名

`augma.yyj.moe` 由现有 Cloudflare Pages 项目 `augma`（`augma.pages.dev`）直接托管同一站点，不再作为跳转入口。项目连接 GitHub `YunYouJun/augma` 的 `main` 分支，使用 Node 24 和 pnpm 12.5.1；构建命令为 `pnpm build`，输出目录为 `apps/site/.vitepress/dist`。推送 `main` 后检查 Pages 构建与部署状态。

在 Pages 项目中将 `augma.yyj.moe` 添加为 Custom Domain，并确认 `yyj.moe` zone 中的 `augma` CNAME 指向 `augma.pages.dev`。Pages 与 DNS 的绑定都完成后，核对 HTTPS 证书和公网访问。站点 canonical 与 sitemap 仍指向主域 `https://augma.yunyoujun.cn`。

## 旧域名

旧入口需要在仍可控制的原托管或 DNS 平台设置。映射规则：

| 旧入口 | 新入口 |
| --- | --- |
| `augma.elpsy.cn/`（旧 Client） | `https://augma.yunyoujun.cn/ar/` |
| `docs.augma.elpsy.cn/` | `https://augma.yunyoujun.cn/guide/` |
| `docs.augma.elpsy.cn/components/button/` 等保留组件 | 对应 `/components/button` |
| 旧 card | `/components/panel` |
| 旧 clock、menu、bottom-menu | `/showcase/` |
| 旧 color | `/design/` |
| 旧 hooks / WebXR 文档 | `/guide/ar` |
| 其余失效页面 | `/guide/migration`，避免误导为相同 API |

这些域名不会随新站发布自动迁移。保留旧站归档，核对旧路径后设置逐路径 301 / 308。2026-10-02 已确认 `augma.elpsy.cn` 与新别名同属 Cloudflare Pages 的 `augma` 项目，旧域迁移应使用按主机名匹配的重定向规则；不要直接添加全站 `/` 重定向，否则会影响新域名。[Pages 的 `_redirects` 不支持域名级匹配](https://developers.cloudflare.com/pages/configuration/redirects/)。

Vercel 仍连接此仓库。根目录 `vercel.json` 覆盖旧的 `pnpm run update` 构建命令，锁定 pnpm 版本并输出完整站点（含 `/ar/`）；Git 预览部署用于验证，不代表旧域迁移或生产发布已完成。[Vercel 仓库配置会覆盖控制台构建设置](https://vercel.com/docs/project-configuration/vercel-json)。

## 公网验收

发布后分别在两个域名检查：首页、一个组件页、`/ar/`、`/llms.txt`、`/components.json`、`/r/button.json`、Markdown 下载。验证 HTTPS、404、移动布局和无路径丢失；重新执行公开 npm / Registry 安装。摄像头与 immersive-ar 需要在实际支持的设备上单独记录结果。


## 2026-10-02 收尾状态

- 本地完整 `pnpm check` 通过，包括 38 项组件测试、4 项发布工具测试、72 项浏览器测试、构建、类型及包 / Registry 消费验证；远端最终提交的 CI / 准备工作流仍需记录实际结果。
- 官方 registry 的 `augma` 最新版本为 `0.1.1`；`@augma/core` 查询返回 404，0.2 尚未完成公开发布。
- 本机 npm 身份验证返回 401；首次注册及 npm trusted publisher 配置尚未确认。GitHub 当前未预设 `npm` environment。
- 主域 `components.json` 可读取但尚未包含本轮新增 API；主域与别名首页已在真实浏览器中确认正常加载。别名站脚本请求曾返回 403，不能据此判断网站故障；新版部署后仍需完成完整公网验收。
- 旧文档根入口仍返回原站，没有跳转到新站。旧站迁移与实机 AR 验收单独记录。

正式宣布发布前，补充工作流 URL、包版本 / integrity、公网安装和两站点验收结果；发布成功后再更新 README、快速开始和 CHANGELOG 中的待发布状态。

## 待办（2026-10-19）

按顺序推进，前一项完成后再开始下一项。宣传视频放在最后，避免观众在 npm 发布和生产部署之前访问到旧站或装到 0.1.1。

- [x] 2026-10-19 的动效与 HudGauge 改动合入 `main`；`dev` 与 `codex/*` 分支已清理，默认分支改为 `main`。
- [ ] 确认 `main` 的 CI、Cloudflare Pages 部署结果，并按需用工作流产物同步 EdgeOne。
- [x] 用 `scripts/capture-media.mjs` 重新生成 README 截图、OG 图与 AR 录屏：README 媒体改为 WebP，OG 图为 JPEG，截图冻结在动画落定的同一时刻；删除未引用的深色与移动端截图。临时截图贴在 issue / PR，不提交到仓库。
- [x] 接入 bumpp：`pnpm release` 更新 5 个版本文件并推送 `v*` 标签，标签自动触发发布；发布前查询 registry，跳过已发布且一致的版本，不一致即停止。
- [x] npm 准备：`augma` 组织早已存在且由 `yunyoujun` 拥有；`augma` 已配置 trusted publisher（GitHub `YunYouJun/augma`、`release.yml`、environment `npm`，权限 publish 与 stage publish）。GitHub 的 `npm` environment 只允许 `v*` 标签部署。
- [ ] 按上文「首次发布 0.2.0」发布：推送 `v0.2.0` 标签触发工作流，用该次 artifact 手动首发 Core 并为它配置 trusted publisher，再对同一次运行 Re-run failed jobs 发布 `augma`。
- [ ] `v0.2.0` 的 GitHub Release 附带 `Augma-macOS.zip` 后，从 `/guide/macos` 下载，在 Apple 芯片与 Intel Mac 上按页面步骤首次打开。
- [ ] 两个域名完成公网验收，从官方 registry 安装 `augma@0.2.0` 并验证 Registry 安装；随后更新 README、快速开始和 CHANGELOG 中的待发布状态。
- [ ] 旧域 `augma.elpsy.cn`、`docs.augma.elpsy.cn` 按主机名逐路径设置 301 / 308。
- [ ] 实机摄像头与 immersive-ar 验收；人工检查 macOS 原生界面（HUD 浮窗、沉浸控制条与开场动画）。
- [ ] 可选：HudGauge 进入 Registry。
- [ ] 以上完成后制作宣传视频：从正式站点实录首页入场、组件动效、空间模式、AR 演示与 macOS 沉浸模式。不使用《刀剑神域》的片段、标志、角色或配乐；提及作品时只说明灵感来源，并附上与版权方无关联的声明。
