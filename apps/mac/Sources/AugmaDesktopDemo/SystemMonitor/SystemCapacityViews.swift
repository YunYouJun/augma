import SwiftUI

enum SystemMetricSeverity {
  case normal, warning, critical, unavailable

  var color: Color {
    switch self {
    case .normal: .augmaCyan
    case .warning: .augmaAccent
    case .critical: .augmaCritical
    case .unavailable: .secondary
    }
  }

  var title: String {
    switch self {
    case .normal: String(localized: "正常")
    case .warning: String(localized: "需关注")
    case .critical: String(localized: "紧张")
    case .unavailable: String(localized: "暂不可用")
    }
  }
}

enum SystemCapacityStyle {
  static func fraction(_ value: Double?) -> Double? {
    guard let value, value.isFinite else { return nil }
    return min(1, max(0, value))
  }

  static func fraction(used: UInt64, total: UInt64) -> Double? {
    guard total > 0 else { return nil }
    return Double(min(used, total)) / Double(total)
  }

  static func diskSeverity(_ disk: DiskUsage?) -> SystemMetricSeverity {
    guard let disk, disk.total > 0 else { return .unavailable }
    let free = Double(min(disk.available, disk.total)) / Double(disk.total)
    // These thresholds describe remaining capacity, not a hardware-health diagnosis.
    if free <= 0.05 { return .critical }
    if free <= 0.10 { return .warning }
    return .normal
  }

  static func batterySeverity(_ battery: BatteryStatus?) -> SystemMetricSeverity {
    guard let battery, fraction(battery.level) != nil else { return .unavailable }
    if !battery.isPluggedIn {
      if battery.level <= 0.10 { return .critical }
      if battery.level <= 0.20 { return .warning }
    }
    return .normal
  }

  static func batteryColor(_ battery: BatteryStatus?) -> Color {
    guard let battery else { return .secondary }
    let severity = batterySeverity(battery)
    if severity == .normal && battery.isCharging { return .augmaHealthy }
    return severity.color
  }

  static func batterySubtitle(_ battery: BatteryStatus) -> String {
    switch batterySeverity(battery) {
    case .warning: String(localized: "电量偏低")
    case .critical: String(localized: "电量不足")
    case .unavailable: String(localized: "暂不可用")
    case .normal: SystemMetricFormat.batteryState(battery)
    }
  }
}

/// A native read-only Gauge with a static Augma ring. No timer, animation or glass layer.
struct SystemCapacityRing: View {
  let title: LocalizedStringKey
  let fraction: Double?
  let symbol: String
  let tint: Color
  var size: CGFloat = 42

  var body: some View {
    Gauge(value: SystemCapacityStyle.fraction(fraction) ?? 0) {
      Text(title)
    } currentValueLabel: {
      Image(systemName: symbol).font(.system(size: size * 0.32, weight: .medium))
    }
    .gaugeStyle(CapacityRingStyle(tint: tint, size: size, available: SystemCapacityStyle.fraction(fraction) != nil))
    .accessibilityValue(SystemCapacityStyle.fraction(fraction).map { SystemMetricFormat.percent($0) } ?? String(localized: "暂不可用"))
    .transaction { $0.animation = nil }
  }
}

private struct CapacityRingStyle: GaugeStyle {
  let tint: Color
  let size: CGFloat
  let available: Bool
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    let width: CGFloat = size < 40 ? 3 : 4
    ZStack {
      Circle().inset(by: width / 2)
        .stroke(Color.secondary.opacity(contrast == .increased ? 0.4 : 0.17),
                style: StrokeStyle(lineWidth: width, dash: available ? [] : [2, 3]))
      // Unavailable readings have a dashed track, never a fabricated zero-percent arc.
      if available && configuration.value > 0 {
        Circle().inset(by: width / 2).trim(from: 0, to: configuration.value)
          .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
          .rotationEffect(.degrees(-90))
      }
      configuration.currentValueLabel.foregroundStyle(available ? tint : .secondary)
        .accessibilityHidden(true)
    }
    .frame(width: size, height: size)
  }
}

private struct SystemCapacityTile: View {
  let title: LocalizedStringKey
  let fraction: Double?
  let symbol: String
  let value: String
  let subtitle: String
  let tint: Color
  let compact: Bool

  var body: some View {
    VStack(spacing: compact ? 3 : 4) {
      SystemCapacityRing(title: title, fraction: fraction, symbol: symbol, tint: tint, size: compact ? 30 : 40)
        .accessibilityHidden(true)
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.system(compact ? .caption : .callout, design: .rounded).weight(.medium)).monospacedDigit()
        .lineLimit(1).minimumScaleFactor(0.8)
      Text(subtitle).font(.caption2).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(title))
    .accessibilityValue([value, fraction.map { SystemMetricFormat.percent($0) }, subtitle].compactMap { $0 }.joined(separator: ", "))
  }
}

struct SystemCapacitySummary: View {
  let snapshot: SystemSnapshot
  var compact = false
  var includesBattery = true

  var body: some View {
    HStack(alignment: .top, spacing: compact ? 8 : 10) {
      // CPU utilization alone is not evidence of a fault: healthy work can use every core.
      SystemCapacityTile(title: "CPU", fraction: snapshot.cpu?.total, symbol: "cpu",
                         value: snapshot.cpu.map { SystemMetricFormat.percent($0.total) } ?? "—",
                         subtitle: String(localized: "当前占用"), tint: snapshot.cpu == nil ? .secondary : .augmaCyan, compact: compact)
      SystemCapacityTile(title: "内存", fraction: snapshot.memory.flatMap { SystemCapacityStyle.fraction(used: $0.used, total: $0.total) },
                         symbol: "memorychip", value: snapshot.memory.map { SystemMetricFormat.bytes($0.used) } ?? "—",
                         subtitle: SystemMetricFormat.pressure(snapshot.memory?.pressure ?? .unknown),
                         tint: SystemMetricFormat.pressureColor(snapshot.memory?.pressure ?? .unknown), compact: compact)
      let disk = snapshot.disks.first
      let diskFraction = disk.flatMap { SystemCapacityStyle.fraction(used: $0.used, total: $0.total) }
      SystemCapacityTile(title: "磁盘", fraction: diskFraction, symbol: "internaldrive",
                         value: diskFraction.map { SystemMetricFormat.percent($0) } ?? "—",
                         subtitle: disk.map { String(format: String(localized: "可用 %@"), SystemMetricFormat.bytes($0.available, style: .file)) }
                           ?? String(localized: "暂不可用"),
                         tint: SystemCapacityStyle.diskSeverity(disk).color, compact: compact)
      if includesBattery, let battery = snapshot.battery {
        SystemCapacityTile(title: "电池", fraction: SystemCapacityStyle.fraction(battery.level),
                           symbol: SystemMetricFormat.batterySymbol(battery), value: SystemMetricFormat.percent(battery.level),
                           subtitle: SystemCapacityStyle.batterySubtitle(battery), tint: SystemCapacityStyle.batteryColor(battery), compact: compact)
      }
    }
  }
}
