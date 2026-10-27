import SwiftUI

enum SystemMonitorDashboardLayout {
  static let spacing: CGFloat = NativePageLayout.sectionSpacing
  static let maximumWidth: CGFloat = NativePageLayout.wideContentWidth

  static func columnCount(for width: CGFloat) -> Int {
    // Two readable 320 pt cards replace the full-width form on desktop windows.
    width >= 320 * 2 + spacing ? 2 : 1
  }
}

struct SystemMonitorMetricCard<Metric: View, Details: View>: View {
  let title: String
  let symbol: String
  @ViewBuilder var metric: Metric
  @ViewBuilder var details: Details

  var body: some View {
    GroupBox {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 14) {
          metric.frame(width: 112)
          Divider().frame(height: 104)
          details.frame(minWidth: 118, maxWidth: .infinity, alignment: .leading)
        }
        VStack(alignment: .leading, spacing: 12) {
          metric.frame(maxWidth: .infinity)
          Divider()
          details
        }
      }
      .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
      .padding(NativePageLayout.itemSpacing)
    } label: {
      Label(title, systemImage: symbol).font(.headline)
    }
    .frame(maxWidth: .infinity, alignment: .top)
  }
}

private struct DashboardMetric: View {
  let title: LocalizedStringKey
  let symbol: String
  let fraction: Double?
  let value: String
  let subtitle: String
  let tint: Color

  var body: some View {
    VStack(spacing: 6) {
      SystemCapacityRing(title: title, fraction: fraction, symbol: symbol, tint: tint, size: 56)
        .accessibilityHidden(true)
      Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
        .lineLimit(1).minimumScaleFactor(0.85)
      Text(subtitle).font(.caption).foregroundStyle(.secondary)
        .lineLimit(2).multilineTextAlignment(.center)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct DashboardFact: View {
  let title: LocalizedStringKey
  let value: String
  var color: Color = .primary

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title).font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: true, vertical: false)
        Spacer(minLength: 0)
        valueText.fixedSize(horizontal: true, vertical: false)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.caption).foregroundStyle(.secondary)
        valueText
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var valueText: some View {
    Text(value).font(.callout).monospacedDigit().foregroundStyle(color)
  }
}

/// The overview is deliberately separate from the live store: layout reads one snapshot
/// and never creates another observation, sampling task or sensor connection.
struct SystemMonitorDashboard: View {
  let snapshot: SystemSnapshot
  let columns: Int
  var sampling = false

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SystemMonitorDashboardLayout.spacing, alignment: .top),
                             count: columns), spacing: SystemMonitorDashboardLayout.spacing) {
      cpu
      memory
      if snapshot.disks.isEmpty {
        SystemMonitorMetricCard(title: String(localized: "磁盘"), symbol: "internaldrive") {
          DashboardMetric(title: "磁盘占用", symbol: "internaldrive", fraction: nil, value: "—",
                          subtitle: String(localized: "暂不可用"), tint: .secondary)
        } details: { SystemMetricUnavailable(sampling: sampling) }
      }
      ForEach(snapshot.disks) { disk in diskCard(disk) }
      battery
    }
  }

  private var cpu: some View {
    SystemMonitorMetricCard(title: String(localized: "CPU"), symbol: "cpu") {
      DashboardMetric(title: "CPU 总占用", symbol: "cpu", fraction: snapshot.cpu?.total,
                      value: snapshot.cpu.map { SystemMetricFormat.percent($0.total) } ?? "—",
                      subtitle: String(localized: "当前占用"), tint: snapshot.cpu == nil ? .secondary : .augmaCyan)
    } details: {
      if let usage = snapshot.cpu {
        VStack(spacing: 12) {
          DashboardFact(title: "用户", value: SystemMetricFormat.percent(usage.user))
          DashboardFact(title: "系统", value: SystemMetricFormat.percent(usage.system))
        }
      } else { SystemMetricUnavailable(sampling: sampling) }
    }
  }

  private var memory: some View {
    SystemMonitorMetricCard(title: String(localized: "内存"), symbol: "memorychip") {
      DashboardMetric(title: "内存占用", symbol: "memorychip",
                      fraction: snapshot.memory.flatMap { SystemCapacityStyle.fraction(used: $0.used, total: $0.total) },
                      value: snapshot.memory.map { SystemMetricFormat.bytes($0.used) } ?? "—",
                      subtitle: snapshot.memory.map { SystemMetricFormat.percent(Double($0.used) / Double(max(1, $0.total))) }
                        ?? String(localized: "暂不可用"),
                      tint: SystemMetricFormat.pressureColor(snapshot.memory?.pressure ?? .unknown))
    } details: {
      if let usage = snapshot.memory {
        VStack(spacing: 10) {
          DashboardFact(title: "总内存", value: SystemMetricFormat.bytes(usage.total))
          DashboardFact(title: "压缩内存", value: SystemMetricFormat.bytes(usage.compressed))
          DashboardFact(title: "交换空间", value: SystemMetricFormat.bytes(usage.swapUsed))
          DashboardFact(title: "内存压力", value: SystemMetricFormat.pressure(usage.pressure), color: SystemMetricFormat.pressureColor(usage.pressure))
        }
      } else { SystemMetricUnavailable(sampling: sampling) }
    }
  }

  private func diskCard(_ disk: DiskUsage) -> some View {
    let fraction = SystemCapacityStyle.fraction(used: disk.used, total: disk.total)
    return SystemMonitorMetricCard(title: disk.name, symbol: "internaldrive") {
      DashboardMetric(title: "磁盘占用", symbol: "internaldrive", fraction: fraction,
                      value: fraction.map { SystemMetricFormat.percent($0) } ?? "—",
                      subtitle: String(localized: "已使用"), tint: SystemCapacityStyle.diskSeverity(disk).color)
    } details: {
      VStack(spacing: 10) {
        DashboardFact(title: "已使用", value: SystemMetricFormat.bytes(disk.used, style: .file))
        DashboardFact(title: "可用空间", value: SystemMetricFormat.bytes(disk.available, style: .file))
        DashboardFact(title: "总容量", value: SystemMetricFormat.bytes(disk.total, style: .file))
        DashboardFact(title: "空间状态", value: SystemCapacityStyle.diskSeverity(disk).title, color: SystemCapacityStyle.diskSeverity(disk).color)
      }
    }
    .help(disk.id)
  }

  private var battery: some View {
    SystemMonitorMetricCard(title: String(localized: "电池"), symbol: snapshot.battery.map { SystemMetricFormat.batterySymbol($0) } ?? "powerplug") {
      DashboardMetric(title: "电池电量", symbol: snapshot.battery.map { SystemMetricFormat.batterySymbol($0) } ?? "powerplug",
                      fraction: snapshot.battery.flatMap { SystemCapacityStyle.fraction($0.level) },
                      value: snapshot.battery.map { SystemMetricFormat.percent($0.level) } ?? "—",
                      subtitle: snapshot.battery.map { SystemCapacityStyle.batterySubtitle($0) } ?? String(localized: "未检测到电池"),
                      tint: SystemCapacityStyle.batteryColor(snapshot.battery))
    } details: {
      if let battery = snapshot.battery {
        VStack(spacing: 12) {
          DashboardFact(title: "电源状态", value: SystemMetricFormat.batteryState(battery))
          if let minutes = battery.minutesRemaining, minutes > 0 {
            DashboardFact(title: battery.isCharging ? "预计充满时间" : "预计剩余时间",
                          value: String(format: String(localized: "%lld 分钟"), minutes))
          }
        }
      } else {
        Text("台式 Mac 可使用其他系统监控功能。").font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

struct SystemMonitorNetworkOverview: View {
  let usage: NetworkUsage?

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 24) {
        download
        Spacer(minLength: 8)
        upload
        Spacer(minLength: 8)
        interface.fixedSize(horizontal: true, vertical: false)
      }
      VStack(alignment: .leading, spacing: 12) {
        HStack { download; Spacer(minLength: 12); upload }
        interface
      }
    }
  }

  private var download: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("下载", systemImage: "arrow.down").font(.caption).foregroundStyle(Color.augmaCyan)
      Text(usage.map { SystemMetricFormat.rate($0.receivedPerSecond) } ?? "—")
        .font(.system(.title3, design: .rounded)).monospacedDigit().fixedSize()
    }
  }

  private var upload: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("上传", systemImage: "arrow.up").font(.caption).foregroundStyle(Color.augmaUpload)
      Text(usage.map { SystemMetricFormat.rate($0.sentPerSecond) } ?? "—")
        .font(.system(.title3, design: .rounded)).monospacedDigit().fixedSize()
    }
  }

  private var interface: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("网络接口").font(.caption).foregroundStyle(.secondary)
      Text(usage?.interfaceDescription ?? "—").font(.system(.title3, design: .rounded))
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
