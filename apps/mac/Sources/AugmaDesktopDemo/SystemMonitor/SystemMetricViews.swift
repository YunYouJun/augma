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
    case .normal: .augmaHealthy
    case .warning: .augmaAccent
    case .critical: .augmaCritical
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

struct SystemNetworkRateSummary: View {
  let usage: NetworkUsage?

  var body: some View {
    HStack(spacing: 16) {
      Label {
        Text(usage.map { SystemMetricFormat.rate($0.receivedPerSecond) } ?? "—").foregroundStyle(.secondary)
      } icon: {
        Image(systemName: "arrow.down").foregroundStyle(Color.augmaCyan).accessibilityLabel("下载")
      }
      Label {
        Text(usage.map { SystemMetricFormat.rate($0.sentPerSecond) } ?? "—").foregroundStyle(.secondary)
      } icon: {
        Image(systemName: "arrow.up").foregroundStyle(Color.augmaUpload).accessibilityLabel("上传")
      }
      Spacer(minLength: 0)
    }
    .font(.caption).monospacedDigit()
  }
}
