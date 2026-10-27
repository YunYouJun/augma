# 原生设备、应用与系统图标

公共模块位于 `apps/mac/Sources/AugmaDesktopDemo/Icons/`，用于各原生页面复用 Apple 设备图标、macOS 应用图标（含第三方应用）和系统平台标识。

## SwiftUI 中使用

```swift
// 已知真实型号：自动查询系统官方图标。
AppleIconView(request: .device(modelIdentifier: "iPhone18,1"), size: 28)

// 系统平台：统一显示 iOS / watchOS 等文字标识。
AppleIconView(request: .platform(.iOS), size: 28)

// 运行中的应用：使用真实 bundle 路径读取原生应用图标。
AppleIconView(request: .application(bundlePath: "/Applications/Google Chrome.app"), size: 24)

// 元数据尚不完整时，仍可按设备类型和平台显示合适的通用符号。
AppleIconView(request: .device(
  simulatorDeviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch",
  platform: .iOS
), size: 28, tint: .secondary)
```

相邻文字已表达设备名称时，在调用处设置 `.accessibilityHidden(true)`；独立使用时由调用处提供无障碍标签。官方图片使用原色、原比例，不重新着色或裁切；`tint` 只影响通用符号。

## 识别与回退规则

`AppleIconRequest` 包含应用 bundle 路径、真实型号、模拟器设备类型或平台，不接受用户可修改的显示名称作为映射依据。`ApplePlatform(runtimeIdentifier:)` 统一识别 `iOS`、`iPadOS`、`watchOS`、`tvOS`、`visionOS`（含 `xrOS`）和 `macOS`。

应用图标通过 `NSWorkspace.icon(forFile:)` 加载，调用前检查绝对路径、`.app` 目录和应用 bundle 元数据。缺失或无效路径回退到通用 `app` 符号；同名应用按完整 bundle 路径分别缓存。应用安装或资源更新后，可调用下述缓存失效接口重新读取。

`AppleIconResolver` 使用 `UTType.types(tag:tagClass:conformingTo:)`，按系统的 `com.apple.device-model-code` 标签查询型号对应的已声明 Apple 类型，再通过 `NSWorkspace.icon(for:)` 加载官方图片。因此 iPhone 17、17 Pro、Duo 等型号共用同一条查询流程，无需为每代设备维护图标文件名。

系统没有相应图片时，先按型号家族、再按模拟器设备类型、最后按平台选择通用 SF Symbol；无法识别时使用中性的矩形。系统平台显示统一的文字标识。多配色图标按类型标识排序，选择第一个可加载的代表配色，不推断设备的真实颜色。所有资源均从本机读取，不复制进应用。

## 缓存与 AppKit 调用

```swift
let resource = AppleIconResolver.shared.resolve(.device(modelIdentifier: "iPhone19,4"))
switch resource {
case .image(let image): /* 直接交给 AppKit 图像控件 */ break
case .symbol(let name): /* 使用该 SF Symbol */ break
case .platformLabel(let name): /* 显示平台标识 */ break
}

// 系统资源更新后，可显式清除缓存，包括之前的未命中记录。
AppleIconResolver.shared.invalidateCache()
```

解析器在主线程使用，按请求缓存成功结果和回退结果，最多保留 256 个请求，不创建后台任务。图像为共享对象，调用者应保持其原始属性；需要修改时先复制。

模拟器清理的适配层只传递身份信息。扫描时通过一次 `simctl list devicetypes --json` 取得设备类型到真实型号的映射，执行复查复用本次目录，列表逐行渲染不启动子进程。目录读取失败会显示说明并回退图标，容量统计与删除保护仍然有效。

验证入口：`AppleIconTests` 和 `SimulatorCleanupTests`。设置 `AUGMA_TEST_APPLE_ICONS=1` 可额外只读验证本机 iPhone 17、17 Pro、Duo 的官方图标；`AUGMA_TEST_SIMULATOR_SCAN=1` 可验证本机模拟器清单。
