import SwiftUI

/// Standalone simulator and application review, independent of optional cleanup providers.
struct SimulatorCleanupPanel: View {
  @ObservedObject var monitor: SystemMonitorStore
  @ObservedObject var store: SimulatorCleanupStore
  @Environment(\.dismiss) private var dismiss
  @State private var observerID = "simulator-cleanup-" + UUID().uuidString

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Label("清理磁盘与内存", systemImage: "sparkles.rectangle.stack")
          .font(.title2.weight(.semibold))
        Spacer()
        Button("完成") { dismiss() }
          .keyboardShortcut(.cancelAction).disabled(store.isCleaning)
          .fixedSize(horizontal: true, vertical: false)
      }
      .padding(NativePageLayout.pagePadding)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing) {
          SimulatorCleanupSection(store: store)
          ApplicationCleanupSection(monitor: monitor, disabled: store.isBusy)
        }
        .nativePageContent()
      }
    }
    .frame(minWidth: 480, idealWidth: 700, minHeight: 600, idealHeight: 740)
    .controlSize(.regular)
    .interactiveDismissDisabled(store.isCleaning)
    .onAppear { monitor.startObserving(observerID, demand: .expanded) }
    .onDisappear {
      monitor.stopObserving(observerID)
      store.cancelReadOnly()
    }
    .onChange(of: store.phase) { _, phase in
      if phase == .idle && store.receipt != nil { Task { await monitor.refresh() } }
    }
  }
}
