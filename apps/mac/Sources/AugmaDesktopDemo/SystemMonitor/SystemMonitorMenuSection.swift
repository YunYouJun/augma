import SwiftUI

struct SystemMonitorMenuSection: View {
  @ObservedObject var store: SystemMonitorStore
  let openMonitor: () -> Void
  @State private var observerID = UUID().uuidString
  @State private var visible = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label {
          Text("系统监控")
        } icon: {
          Image(systemName: "gauge.with.dots.needle.50percent").foregroundStyle(Color.augmaCyan)
        }
        .font(.headline)
        Spacer()
        Button("查看详情", action: openMonitor)
      }
      if !store.enabled {
        Button("开启系统监控") { store.enabled = true }.nativeFloatingButton()
      } else if store.menuBarSummaryEnabled {
        SystemMonitorSummary(store: store)
        if store.applicationMemoryEnabled {
          ApplicationMemoryMenuSummary(snapshot: store.snapshot.applicationMemory, sampling: store.isSampling)
        }
        if store.sensorsEnabled { HardwareSensorMetrics(snapshot: store.snapshot.sensors, compact: true).font(.caption) }
        if store.networkHistoryEnabled { NetworkHistoryView(history: store.networkHistory, compact: true) }
      }
      Toggle("固定系统监控到 HUD", isOn: $store.hudPinned)
        .toggleStyle(.checkbox)
    }
    .background {
      SystemMonitorVisibilityView(includeWhileApplicationHidden: true) { isVisible in
        visible = isVisible
        updateObservation()
      }
      .frame(width: 0, height: 0)
    }
    .onDisappear { visible = false; store.stopObserving(observerID) }
    .onChange(of: store.menuBarSummaryEnabled) { _, _ in updateObservation() }
  }

  private func updateObservation() {
    if visible && store.menuBarSummaryEnabled { store.startObserving(observerID, demand: .expanded) }
    else { store.stopObserving(observerID) }
  }
}
