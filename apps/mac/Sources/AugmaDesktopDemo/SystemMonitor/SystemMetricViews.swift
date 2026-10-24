import Foundation
import SwiftUI

enum SystemMetricFormat {
  static func percent(_ value: Double) -> String {
    min(1, max(0, value)).formatted(.percent.precision(.fractionLength(0)))
  }

  static func bytes(_ value: UInt64, style: ByteCountFormatter.CountStyle = .binary) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: style)
  }

  static func rate(_ value: Double) -> String {
    guard value.isFinite, value >= 0 else { return "—" }
    let bytes = Int64(min(value, Double(Int64.max - 2048)))
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + "/s"
  }

  static func pressure(_ pressure: MemoryPressure) -> String {
    switch pressure {
    case .normal: String(localized: "正常")
    case .warning: String(localized: "偏高")
    case .critical: String(localized: "紧张")
    case .unknown: String(localized: "暂不可用")
    }
  }

  static func pressureColor(_ pressure: MemoryPressure) -> Color {
    switch pressure {
    case .normal: .green
    case .warning: .orange
    case .critical: .red
    case .unknown: .secondary
    }
  }

  static func batteryState(_ battery: BatteryStatus) -> String {
    if battery.isCharging { return String(localized: "正在充电") }
    return battery.isPluggedIn ? String(localized: "已连接电源") : String(localized: "使用电池")
  }

  static func batterySymbol(_ battery: BatteryStatus) -> String {
    if battery.isCharging { return "battery.100percent.bolt" }
    switch battery.level {
    case ..<0.125: return "battery.0percent"
    case ..<0.375: return "battery.25percent"
    case ..<0.625: return "battery.50percent"
    case ..<0.875: return "battery.75percent"
    default: return "battery.100percent"
    }
  }
}

struct SystemMetricUnavailable: View {
  var sampling = false

  var body: some View {
    Text(sampling ? String(localized: "正在采样…") : String(localized: "暂不可用"))
      .foregroundStyle(.secondary)
  }
}

struct SystemCPUMetrics: View {
  let usage: CPUUsage?
  let sampling: Bool

  var body: some View {
    if let usage {
      LabeledContent("总占用", value: SystemMetricFormat.percent(usage.total))
        .monospacedDigit()
      ProgressView(value: min(1, max(0, usage.total)))
        .accessibilityLabel("CPU 总占用")
      LabeledContent("用户", value: SystemMetricFormat.percent(usage.user))
        .monospacedDigit()
      LabeledContent("系统", value: SystemMetricFormat.percent(usage.system))
        .monospacedDigit()
    } else {
      SystemMetricUnavailable(sampling: sampling)
    }
  }
}

struct SystemMemoryMetrics: View {
  let usage: MemoryUsage?

  var body: some View {
    if let usage {
      LabeledContent("已使用", value: SystemMetricFormat.bytes(usage.used))
      ProgressView(value: Double(usage.used), total: Double(max(1, usage.total)))
        .tint(SystemMetricFormat.pressureColor(usage.pressure))
        .accessibilityLabel("内存占用")
      LabeledContent("总内存", value: SystemMetricFormat.bytes(usage.total))
      LabeledContent("压缩内存", value: SystemMetricFormat.bytes(usage.compressed))
      LabeledContent("交换空间", value: SystemMetricFormat.bytes(usage.swapUsed))
      LabeledContent("内存压力") {
        Text(SystemMetricFormat.pressure(usage.pressure))
          .foregroundStyle(SystemMetricFormat.pressureColor(usage.pressure))
      }
    } else {
      SystemMetricUnavailable()
    }
  }
}

struct SystemDiskMetrics: View {
  let disk: DiskUsage

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(disk.name, systemImage: "internaldrive")
        .font(.headline)
        .lineLimit(1)
        .help(disk.id)
      ProgressView(value: Double(disk.used), total: Double(max(1, disk.total)))
        .accessibilityLabel("磁盘占用")
      LabeledContent("已使用", value: SystemMetricFormat.bytes(disk.used, style: .file))
      LabeledContent("可用空间", value: SystemMetricFormat.bytes(disk.available, style: .file))
      LabeledContent("总容量", value: SystemMetricFormat.bytes(disk.total, style: .file))
    }
    .padding(.vertical, 4)
  }
}

struct SystemNetworkMetrics: View {
  let usage: NetworkUsage?
  let sampling: Bool

  var body: some View {
    if let usage {
      LabeledContent {
        Text(SystemMetricFormat.rate(usage.receivedPerSecond)).monospacedDigit()
      } label: {
        Label("下载", systemImage: "arrow.down")
      }
      LabeledContent {
        Text(SystemMetricFormat.rate(usage.sentPerSecond)).monospacedDigit()
      } label: {
        Label("上传", systemImage: "arrow.up")
      }
      LabeledContent("网络接口", value: usage.interface)
    } else {
      SystemMetricUnavailable(sampling: sampling)
    }
  }
}

struct SystemBatteryMetrics: View {
  let battery: BatteryStatus?

  var body: some View {
    if let battery {
      LabeledContent {
        Text(SystemMetricFormat.percent(battery.level)).monospacedDigit()
      } label: {
        Label("电量", systemImage: SystemMetricFormat.batterySymbol(battery))
      }
      ProgressView(value: min(1, max(0, battery.level)))
        .tint(battery.level < 0.2 && !battery.isPluggedIn ? .orange : .accentColor)
        .accessibilityLabel("电池电量")
      LabeledContent("电源状态", value: SystemMetricFormat.batteryState(battery))
      if let minutes = battery.minutesRemaining, minutes > 0 {
        LabeledContent(battery.isCharging ? "预计充满时间" : "预计剩余时间") {
          Text(String(format: String(localized: "%lld 分钟"), minutes))
        }
      }
    } else {
      Label("未检测到电池", systemImage: "powerplug")
        .foregroundStyle(.secondary)
      Text("台式 Mac 可使用其他系统监控功能。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}
