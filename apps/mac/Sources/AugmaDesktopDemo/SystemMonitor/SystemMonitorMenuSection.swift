import SwiftUI

struct SystemMonitorMenuSection: View {
  @ObservedObject var store: SystemMonitorStore
  let openMonitor: () -> Void
  @State private var observerID = UUID().uuidString
  @State private var visible = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("系统监控", systemImage: "gauge.with.dots.needle.50percent").font(.headline)
        Spacer()
        Button("查看详情", action: openMonitor)
      }
      if store.menuBarSummaryEnabled { SystemMonitorSummary(store: store) }
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
    if visible && store.menuBarSummaryEnabled { store.startObserving(observerID) }
    else { store.stopObserving(observerID) }
  }
}
