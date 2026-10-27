import SwiftUI

struct SystemMonitorView: View {
  @ObservedObject var store: SystemMonitorStore
  @State private var observerID = "system-detail-" + UUID().uuidString
  @State private var refreshing = false
  @State private var showingCleanup = false

  var body: some View {
    GeometryReader { geometry in
      let width = min(SystemMonitorDashboardLayout.maximumWidth,
                      max(0, geometry.size.width - NativePageLayout.pagePadding * 2))
      ScrollView {
        LazyVStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing) {
          controls
          if store.enabled {
            SystemMonitorDashboard(snapshot: store.snapshot,
                                   columns: SystemMonitorDashboardLayout.columnCount(for: width), sampling: store.isSampling)
            if store.sensorsEnabled {
              GroupBox {
                VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
                  HardwareSensorMetrics(snapshot: store.snapshot.sensors)
                  Text("传感器最快每 5 秒读取一次，读取后立即关闭连接。机型或系统限制可能导致部分读数不可用。")
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
              } label: { Label("温度与风扇", systemImage: "thermometer.medium").font(.headline) }
            }
            if store.applicationMemoryEnabled { ranking }
            GroupBox {
              VStack(alignment: .leading, spacing: 12) {
                SystemMonitorNetworkOverview(usage: store.snapshot.network)
                if store.networkHistoryEnabled { NetworkHistoryView(history: store.networkHistory) }
                Text("仅统计自动选择的物理网卡，包含互联网和局域网流量，不叠加 VPN 虚拟接口或本机回环流量。网速不是带宽测速；切换网卡或唤醒后会重新采样。")
                  .font(.caption).foregroundStyle(.secondary)
              }
              .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
            } label: { Label("当前网卡流量", systemImage: "network").font(.headline) }
          } else {
            GroupBox {
              VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
                Label("系统监控已暂停", systemImage: "pause.circle")
                Text("开启后仅在监控界面可见时工作；也可选择仅手动刷新。")
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading).padding(NativePageLayout.itemSpacing)
            }
          }
        }
        .nativePageContent(maxWidth: SystemMonitorDashboardLayout.maximumWidth)
      }
    }
    .controlSize(.regular)
    .background {
      SystemMonitorVisibilityView { visible in
        if visible { store.startObserving(observerID, demand: .expanded) }
        else { store.stopObserving(observerID) }
      }
      .frame(width: 0, height: 0)
    }
    .onDisappear { store.stopObserving(observerID) }
    .sheet(isPresented: $showingCleanup) { SystemCleanupView(monitor: store, store: store.cleanup) }
  }

  private var controls: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 20) {
            enabledToggle.fixedSize()
            pinToggle.fixedSize()
            Spacer(minLength: 12)
            updatedAt.fixedSize()
            refreshButton
          }
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
            enabledToggle
            pinToggle
            HStack { updatedAt; Spacer(minLength: 8); refreshButton }
          }
        }
        DisclosureGroup("采集选项") {
          SystemMonitorFeatureControls(store: store).padding(.top, 8)
        }
        Button("清理磁盘与内存", systemImage: "sparkles.rectangle.stack") { showingCleanup = true }
          .nativeFloatingButton()
      }
      .padding(NativePageLayout.itemSpacing)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var enabledToggle: some View {
    Toggle("启用系统监控", isOn: $store.enabled).toggleStyle(.switch)
  }

  private var pinToggle: some View {
    Toggle("在 HUD 固定显示系统指标", isOn: $store.hudPinned).toggleStyle(.switch)
  }

  private var updatedAt: some View {
    HStack(spacing: 6) {
      Text("上次更新")
      if store.enabled && store.snapshot.memory != nil {
        Text(store.snapshot.sampledAt, format: .dateTime.hour().minute().second()).monospacedDigit()
      } else { Text("—") }
    }
    .font(.caption).foregroundStyle(.secondary)
  }

  private var refreshButton: some View {
    Button("刷新", systemImage: "arrow.clockwise") {
      Task {
        refreshing = true
        await store.refresh()
        refreshing = false
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .nativeFloatingButton()
    .disabled(!store.enabled || refreshing || store.isSampling)
  }

  private var ranking: some View {
    GroupBox {
      LazyVStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
        ApplicationMemoryRanking(snapshot: store.snapshot.applicationMemory, sampling: store.isSampling)
        DisclosureGroup("统计说明") {
          Text("汇总当前用户应用及可确认归属的辅助进程，条形以首位应用为基准。占用包含压缩内存，与系统已用内存的统计口径不同。无法确认归属的共享系统服务不计入；部分进程不可读取时，占用可能不完整。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .padding(NativePageLayout.itemSpacing)
    } label: {
      Label("应用内存排行", systemImage: "chart.bar.xaxis").font(.headline)
    }
  }
}

struct SystemMonitorSummary: View {
  @ObservedObject var store: SystemMonitorStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      SystemCapacitySummary(snapshot: store.snapshot)
      SystemNetworkRateSummary(usage: store.snapshot.network)
    }
  }
}

struct SystemMonitorHUD: View {
  @ObservedObject var store: SystemMonitorStore

  var body: some View {
    if store.enabled { metrics }
    else { Label("系统监控已暂停", systemImage: "pause.circle").foregroundStyle(.secondary) }
  }

  private var metrics: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("系统监控", systemImage: "gauge.with.dots.needle.50percent")
          .font(.headline)
        Spacer()
        if let battery = store.snapshot.battery {
          Label(SystemMetricFormat.percent(battery.level), systemImage: SystemMetricFormat.batterySymbol(battery))
            .foregroundStyle(SystemCapacityStyle.batteryColor(battery))
        }
      }
      SystemCapacitySummary(snapshot: store.snapshot, compact: true, includesBattery: false)
      Divider()
      SystemNetworkRateSummary(usage: store.snapshot.network)
      if store.snapshot.cpu == nil || store.snapshot.network == nil {
        SystemMetricUnavailable(sampling: store.isSampling).font(.caption)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .monospacedDigit()
    .accessibilityElement(children: .contain)
  }
}
