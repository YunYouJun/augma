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

- `dev` 是默认开发分支；功能与发布准备 PR 先合入 `dev`。CI 覆盖 `dev`、`main` 的 push，以及所有 PR。
- `main` 是 Cloudflare Pages 的生产分支。不要在 npm 包尚不可安装时把新的安装文档合入 `main`；普通 Git 推送会触发站点部署，不能用它代替 npm 发布。
- 从通过检查的 `dev` 提交准备产物；正式发布使用该提交的 `v0.2.0` 标签。先发布 Core，再发布 Vue，验证公开安装后将同一提交通过发布 PR 合入 `main`。
- 合并生产分支时保留发布提交历史，不使用 squash / rebase 改写已打标签的提交。EdgeOne 使用该发布工作流保存的站点 artifact，两个站点保持相同内容。

## 准备产物（不发布）

在干净、已提交的工作区执行：

```sh
pnpm check
pnpm release:pack
pnpm release:verify
```

`release-artifacts/` 包含两个 `.tgz` 和 `manifest.json`。清单记录版本、完整 Git 提交 SHA、固定包名与 SHA-512 integrity；目录被 Git 忽略。验证拒绝不同提交、修改过的 tarball、缺失包或额外文件。`release:pack` 只打包，必须先成功执行 `pnpm check`，不会发布或创建版本标签。

GitHub Actions 的 **Prepare or publish packages**（`release.yml`）默认 `publish=false`，可在开发或发布准备分支手动运行。它完成检查后保存包与站点 artifact，名称包含提交 SHA、运行 ID 与尝试次数。准备任务不使用 npm environment 或写权限。

## npm 正式发布

目标版本为 `0.2.0`。根 package.json、Core、Vue 包和 `scripts/catalog.mjs` 必须保持一致；变更说明维护在 [CHANGELOG](../CHANGELOG.md)。

1. 核对 `augma` 维护权限及 `@augma` scope / `@augma/core` 创建与发布权限。用 `npm whoami --registry=https://registry.npmjs.org` 验证登录；不要把 Token 或验证码写入仓库。
2. 两个包分别配置 npm trusted publisher：GitHub 仓库 `YunYouJun/augma`、工作流文件 `release.yml`、environment `npm`，并允许直接 `npm publish`。首次注册 `@augma/core` 若无法预配 trusted publisher，应由维护者使用已验证 tarball 完成注册，然后配置后续 OIDC 发布。
3. 在 GitHub 配置匹配的 `npm` environment。当前工作流使用 GitHub 托管 runner 和 `id-token: write`；发布前会检查 npm CLI 至少为 11.5.1。
4. 确认发布提交通过检查，再创建匹配的 `v0.2.0` 标签。在该标签上运行 **Prepare or publish packages**，明确设置 `publish=true`。非匹配标签会在构建前失败。
5. 发布任务下载本次准备任务的原始 tarball，验证提交与摘要后按 Core → Vue 顺序发布，不重新构建。完成后自动核对公开版本、`latest` 和 tarball integrity。
6. 在干净目录用官方 registry 安装 `augma@0.2.0`、构建最小 Vue 项目，再用正式域名执行 Registry 安装验证。只有此时才能宣布公开安装可用。

[npm 官方 trusted publishing 文档](https://docs.npmjs.com/trusted-publishers/) 要求在包设置中配置 workflow、可选 environment 及允许的操作；仓库工作流文件本身不能代替 npm 端授权。

### 首次注册或部分发布失败

npm 发布没有跨包事务。Core 成功而 Vue 失败时，不要直接重跑整个发布任务：

1. 保留该次工作流的包 artifact，将清单和两个包下载到对应提交的 `release-artifacts/`。
2. 运行 `pnpm release:verify`；对照 `npm view @augma/core@0.2.0 dist.integrity --registry=https://registry.npmjs.org` 与清单，确认已发布包完全一致。
3. 维护者在本地登录后，仅发布尚未发布的 tarball。例如 Vue 未发布时运行 `npm publish release-artifacts/augma-0.2.0.tgz --access public --registry=https://registry.npmjs.org`。本地恢复发布不声明 GitHub OIDC provenance。
4. 两包发布完成后运行 `pnpm release:check-published`，再继续公网安装验收。如果同版本的公开 integrity 与清单不同，停止并核查；不能覆盖 npm 上已存在的版本。

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

## 公网验收

发布后分别在两个域名检查：首页、一个组件页、`/ar/`、`/llms.txt`、`/components.json`、`/r/button.json`、Markdown 下载。验证 HTTPS、404、移动布局和无路径丢失；重新执行公开 npm / Registry 安装。摄像头与 immersive-ar 需要在实际支持的设备上单独记录结果。


## 2026-10-02 收尾状态

- 本地完整 `pnpm check` 通过，包括 38 项组件测试、4 项发布工具测试、72 项浏览器测试、构建、类型及包 / Registry 消费验证；远端最终提交的 CI / 准备工作流仍需记录实际结果。
- 官方 registry 的 `augma` 最新版本为 `0.1.1`；`@augma/core` 查询返回 404，0.2 尚未完成公开发布。
- 本机 npm 身份验证返回 401；首次注册及 npm trusted publisher 配置尚未确认。GitHub 当前未预设 `npm` environment。
- 主域 `components.json` 可读取但尚未包含本轮新增 API；别名站脚本请求返回 403，需从真实浏览器和托管平台完成验收。
- 旧文档根入口仍返回原站，没有跳转到新站。旧站迁移与实机 AR 验收单独记录。

正式宣布发布前，补充工作流 URL、包版本 / integrity、公网安装和两站点验收结果；发布成功后再更新 README、快速开始和 CHANGELOG 中的待发布状态。
