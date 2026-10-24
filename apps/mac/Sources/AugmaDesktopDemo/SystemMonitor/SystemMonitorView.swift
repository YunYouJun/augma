import SwiftUI

struct SystemMonitorView: View {
  @ObservedObject var store: SystemMonitorStore
  @State private var observerID = "system-detail-" + UUID().uuidString
  @State private var refreshing = false

  var body: some View {
    Form {
      Section {
        Toggle("在 HUD 固定显示系统指标", isOn: $store.hudPinned)
        HStack {
          LabeledContent("上次更新") {
            Text(store.snapshot.sampledAt, format: .dateTime.hour().minute().second())
              .monospacedDigit().foregroundStyle(.secondary)
          }
          Button("刷新", systemImage: "arrow.clockwise") {
            Task {
              refreshing = true
              await store.refresh()
              refreshing = false
            }
          }
          .disabled(refreshing || store.isSampling)
        }
      }

      Section("CPU") {
        SystemCPUMetrics(usage: store.snapshot.cpu, sampling: store.isSampling)
      }
      Section("内存") {
        SystemMemoryMetrics(usage: store.snapshot.memory)
      }
      Section("磁盘") {
        if store.snapshot.disks.isEmpty {
          SystemMetricUnavailable()
        } else {
          ForEach(store.snapshot.disks) { disk in SystemDiskMetrics(disk: disk) }
        }
      }
      Section {
        SystemNetworkMetrics(usage: store.snapshot.network, sampling: store.isSampling)
      } header: {
        Text("网络")
      } footer: {
        Text("网速表示当前网络接口的实际流量，不是网络带宽测速。切换接口或从睡眠中恢复后会重新采样。")
      }
      Section("电池") {
        SystemBatteryMetrics(battery: store.snapshot.battery)
      }
    }
    .formStyle(.grouped)
    .background {
      SystemMonitorVisibilityView { visible in
        if visible { store.startObserving(observerID) }
        else { store.stopObserving(observerID) }
      }
      .frame(width: 0, height: 0)
    }
    .onDisappear { store.stopObserving(observerID) }
  }
}

struct SystemMonitorSummary: View {
  @ObservedObject var store: SystemMonitorStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 20) {
        summary("CPU", symbol: "cpu", value: store.snapshot.cpu.map { SystemMetricFormat.percent($0.total) })
        Spacer(minLength: 0)
        summary("内存", symbol: "memorychip", value: store.snapshot.memory.map { SystemMetricFormat.bytes($0.used) })
        if let battery = store.snapshot.battery {
          Spacer(minLength: 0)
          summary("电池", symbol: SystemMetricFormat.batterySymbol(battery), value: SystemMetricFormat.percent(battery.level))
        }
      }
      HStack(spacing: 16) {
        Label {
          Text(store.snapshot.network.map { SystemMetricFormat.rate($0.receivedPerSecond) } ?? "—")
        } icon: {
          Image(systemName: "arrow.down").accessibilityLabel("下载")
        }
        Label {
          Text(store.snapshot.network.map { SystemMetricFormat.rate($0.sentPerSecond) } ?? "—")
        } icon: {
          Image(systemName: "arrow.up").accessibilityLabel("上传")
        }
        Spacer(minLength: 0)
        if let disk = store.snapshot.disks.first {
          Text(String(format: String(localized: "可用 %@"), SystemMetricFormat.bytes(disk.available, style: .file)))
        }
      }
      .font(.caption).monospacedDigit().foregroundStyle(.secondary)
    }
  }

  private func summary(_ title: LocalizedStringKey, symbol: String, value: String?) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
      Text(value ?? "—").font(.system(.body, design: .rounded)).monospacedDigit()
    }
  }
}

struct SystemMonitorHUD: View {
  @ObservedObject var store: SystemMonitorStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("系统监控", systemImage: "gauge.with.dots.needle.50percent")
          .font(.headline)
        Spacer()
        if let battery = store.snapshot.battery {
          Label(SystemMetricFormat.percent(battery.level), systemImage: SystemMetricFormat.batterySymbol(battery))
            .foregroundStyle(.secondary)
        }
      }
      HStack(alignment: .firstTextBaseline, spacing: 24) {
        metric("CPU", value: store.snapshot.cpu.map { SystemMetricFormat.percent($0.total) })
        Spacer(minLength: 0)
        metric("内存", value: store.snapshot.memory.map { SystemMetricFormat.bytes($0.used) })
        Spacer(minLength: 0)
        metric("磁盘可用", value: store.snapshot.disks.first.map { SystemMetricFormat.bytes($0.available, style: .file) })
      }
      Divider()
      HStack(spacing: 20) {
        Label {
          Text(store.snapshot.network.map { SystemMetricFormat.rate($0.receivedPerSecond) } ?? "—")
        } icon: {
          Image(systemName: "arrow.down").accessibilityLabel("下载")
        }
        Label {
          Text(store.snapshot.network.map { SystemMetricFormat.rate($0.sentPerSecond) } ?? "—")
        } icon: {
          Image(systemName: "arrow.up").accessibilityLabel("上传")
        }
        Spacer(minLength: 0)
      }
      .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
      if store.snapshot.cpu == nil || store.snapshot.network == nil {
        SystemMetricUnavailable(sampling: store.isSampling).font(.caption)
      }
    }
    .padding(12)
    .monospacedDigit()
    .accessibilityElement(children: .contain)
  }

  private func metric(_ title: LocalizedStringKey, value: String?) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value ?? "—")
        .font(.system(size: 23, weight: .light, design: .rounded))
        .lineLimit(1).minimumScaleFactor(0.7)
    }
  }
}
