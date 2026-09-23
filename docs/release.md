# 0.2 发布与域名迁移

站点部署到 EdgeOne Pages；npm 包发布、别名域跳转和旧站迁移分别处理。公开安装命令依赖 0.2.0 包发布。

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

## npm

公开版本暂定 `0.2.0`。根 package.json、Core、Vue 包和 `scripts/catalog.mjs` 必须保持一致。

1. 核对 `augma` 的维护权限以及 `@augma` scope / `@augma/core` 的创建与发布权限。
2. 配置两个包的 npm trusted publisher：GitHub 仓库 `YunYouJun/augma`、工作流 `release.yml`、environment `npm`。新包如不能预先配置 trusted publisher，先完成 npm 的首次包注册流程，再启用此工作流。
3. 为已审阅的提交创建匹配版本的 `v0.2.0` 标签，在该标签上手动运行 **Publish packages**。流程拒绝分支或不一致的版本，检查后打包、上传同一份 tarball，再依次发布 Core、Vue。
4. Core 发布成功而 Vue 失败时，先检查 npm 的实际状态；从已验证的 artifact 恢复 Vue 发布，避免盲目重复发布 Core。npm 发布没有跨包事务。
5. 两包均可安装后再发布公开文档与 Registry，防止公开安装命令指向未发布版本。

OIDC 需要支持 trusted publishing 的 npm CLI（Node 24 环境），参照 [npm 官方文档](https://docs.npmjs.com/trusted-publishers/)。仓库没有保存发布令牌。

2026-09-22 本地 DNS 核查：两个新域名尚无 A / CNAME 解析；旧文档域指向 Vercel，旧 Client 域由 Cloudflare 代理。

## 主域名与站点

主站是 `https://augma.yunyoujun.cn`，文档、展示、AI 静态入口和 `/ar/` 一起部署。

- EdgeOne Pages 项目 `augma`（`makers-qvfxx56v4tcl`）使用海外加速区，生产环境部署 `apps/site/.vitepress/dist`。
- 代码推送到 `main` 后，CI 验证并保存站点 artifact；生产部署从已验证的本地构建手动执行：

  ```sh
  pnpm check
  edgeone pages deploy apps/site/.vitepress/dist -n augma -e production -a overseas
  ```

- `augma.yunyoujun.cn` 在 EdgeOne Pages 项目中绑定到 Production。Cloudflare DNS 配置两条 DNS-only CNAME：`augma.yunyoujun.cn → augma.yunyoujun.cn.pages.dnsoe5.com` 用于站点访问，`_dnsauth.augma.yunyoujun.cn → augma.yunyoujun.cn.eoacme0.com` 用于免费 HTTPS 证书验证和续期。核对 HTTPS 证书和公网访问。
- canonical、sitemap、Skill 与生成索引均采用主域。域名绑定与 DNS 配置需在托管平台完成。

## 别名域跳转

`deploy/redirect/` 提供独立 Cloudflare Worker：只接管 `augma.yyj.moe`，返回保留路径与查询参数的 308。主域不会被此 Worker 接管，不会形成跳转循环。

在 yyj.moe 已加入目标 Cloudflare 账户、核对现有 DNS 后，用已认证的 Wrangler 执行：

```sh
wrangler deploy --config deploy/redirect/wrangler.jsonc
```

此操作需要 Cloudflare 账户和 zone 权限，未在本地实施中运行。Custom Domain 会管理该域名的路由与证书，参照 [Cloudflare 官方说明](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)。若使用其他托管商，同样应在服务端配置保留路径与查询参数的 301 / 308，不能依赖前端 JavaScript 跳转。

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

这些域名不在当前 Worker 的自动接管范围内。保留旧站归档，核对旧路径后设置逐路径 301 / 308。

## 公网验收

发布后检查：首页、一个组件页、`/ar/`、`/llms.txt`、`/components.json`、`/r/button.json`、Markdown 下载；别名域 `/components/button?theme=dark` 应单次跳转到主域对应 URL。验证 HTTPS、404、移动布局和无路径丢失；重新执行公开 npm / Registry 安装。摄像头与 immersive-ar 需要在实际支持的设备上单独记录结果。
