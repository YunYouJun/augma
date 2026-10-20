# 序列之争视觉与动效完善

日期：2026-10-19。目标：让组件库、主站和 macOS 演示更接近《刀剑神域：序列之争》中 Augma 的 AR 界面——发光的玻璃、环形 HUD、先现亮线再展开的窗口，以及有节制的强调色。AR 演示继续遵守[原站还原约定](./ar-original-site-fidelity.md)，只同步新 tokens 的取值。

## 已完成

- [x] Core 新增 `--agm-light`、`--agm-sheen`、`--agm-glow` 与 `--agm-duration-slow`、`--agm-ease*`；新增 `.agm-materialize` 工具类（`--agm-delay` 编排，结束后不残留裁剪）。
- [x] 组件动效：Dialog 浮现 / 折叠与一次扫描线；Select 展开；Tooltip 按方向滑入；Toast 滑入、滑动关闭与可暂停倒计时线；Button 光扫与按压；IconButton 环绕弧线、`pressed` 强调色填充；输入框底部扫描线；开关回弹；滑块刻度与光晕；HudStatus 声呐；HudProgress 发光前沿、环形 60 刻度与绘制入场。
- [x] 新增 `AgmHudGauge`（第 13 个组件）：`meter` 语义、数值约束、剩余 50% / 20% 切换警示 / 危险色、下降余影。目录、示例、文档、契约与测试同步；本轮暂不进入 Registry，2026-10-20 作为第 7 个条目加入。
- [x] 主站：HudOrbit 轨道环（刻度、反向弧线、雷达扫描、信标），空间模式下倒为地面环；面板指针倾斜；标题光扫与逐行浮现；六边形场域定时扫描；目标框悬停收拢；`animation-timeline: view()` 渐进增强的滚动浮现；示例画布点阵。
- [x] macOS：`AugmaStyle.swift` 提供颜色、切角按钮（悬停光扫）、AugmaRing、StatusPing、角标、HudBrackets、浮现修饰器；HUD 浮窗、沉浸控制条、侧栏品牌区改用该语言；进入沉浸模式播放扫描线 + 涟漪开场（不拦截输入，减少动态效果时跳过）。

## 验证

`pnpm generate`、ESLint、vue-tsc、39 项单元测试、完整构建、npm 包消费（13 个导出）、6 个 Registry 条目的真实 CLI 安装，以及 Chromium / Firefox / WebKit 共 78 项浏览器测试通过。`swift build` 无警告，4 项 Swift 测试通过。浏览器中人工检查了 1000px 与 390px、浅色与深色、Dialog 浮现中间帧、场域扫描中间帧、空间模式和 AR 演示外观。

macOS 应用已打包并启动，演示窗口出现在屏幕上；`mac:verify` 读取窗口标题需要屏幕录制权限，本次环境未授权，因此该脚本报告失败。原生界面的视觉效果尚未人工截图核对。

## 仍待处理

按[发布说明中的待办](../release.md#待办2026-10-19)顺序推进。截至 2026-10-20，`main` 部署、展示素材、npm 发布与公网验收、旧域跳转均已完成；剩下实机与 macOS 人工检查，之后再做宣传视频。在线属性编辑器和框架适配仍是后续候选。
