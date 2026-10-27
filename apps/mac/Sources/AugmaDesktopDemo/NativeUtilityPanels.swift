import SwiftUI

struct NativeNotificationsView: View {
  @ObservedObject var store: NativeNotificationStore

  var body: some View {
    NativePage {
      NativePageSection("应用通知") {
        Text("记录本次窗口会话中的 Augma 操作，不会读取 macOS 通知中心。")
          .font(.callout).foregroundStyle(.secondary)
        Button("清空通知", systemImage: "trash", action: store.clear)
          .buttonStyle(.bordered)
          .disabled(store.notices.isEmpty)
          .accessibilityIdentifier("native-notifications-clear")
      }
      if store.notices.isEmpty {
        ContentUnavailableView("暂无应用通知", systemImage: "bell", description: Text("扫描空间、切换场景或操作设备后，新的记录会出现在这里。"))
          .frame(maxWidth: .infinity)
          .accessibilityIdentifier("native-notifications-empty")
      } else {
        ForEach(store.notices) { notice in
          HStack(alignment: .top, spacing: NativePageLayout.itemSpacing) {
            Image(systemName: notice.symbol)
              .font(.title3).foregroundStyle(.tint)
              .frame(width: 24)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: NativePageLayout.itemSpacing) {
                Text(notice.title).font(.headline)
                  .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(notice.date, style: .time)
                  .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                  .fixedSize()
              }
              Text(notice.detail).font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .nativeCard()
          .accessibilityElement(children: .contain)
        }
      }
    }
    .textSelection(.enabled)
    .accessibilityIdentifier("native-notifications")
    .onAppear(perform: store.markAllRead)
    .onChange(of: store.notices.first?.id) { _, _ in store.markAllRead() }
  }
}

struct NativeDeviceView: View {
  @ObservedObject var store: NativeDeviceStore
  @ObservedObject var space: NativeSpaceStore
  @ObservedObject var camera: NativeCameraStore
  @ObservedObject var preferences: NativePreferencesStore

  var body: some View {
    NativePage {
      NativePageSection("模拟设备") {
        HStack(spacing: NativePageLayout.itemSpacing) {
          Label(store.connection.title, systemImage: store.online ? "checkmark.circle" : "pause.circle")
            .accessibilityIdentifier("native-device-connection")
          if store.connection == .connecting { ProgressView().controlSize(.small) }
        }
        Text("此面板模拟 Augma 设备连接，不代表真实头显或蓝牙设备的连接状态。")
          .font(.callout).foregroundStyle(.secondary)
        Divider()
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { connectionActions }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { connectionActions }
        }
        .controlSize(.large)
      }
      NativePageSection("当前状态") {
        DeviceStatusRow("模拟场景", value: space.scene.title(locale: preferences.locale))
          .accessibilityIdentifier("native-device-scene")
        DeviceStatusRow("当前地标", value: space.selected.title(locale: preferences.locale))
        DeviceStatusRow("摄像头", value: cameraStatus)
          .accessibilityIdentifier("native-device-camera")
        DeviceStatusRow("模拟扫描", value: space.scanning ? String(localized: "扫描中") : "\(Int(space.scanProgress))%")
        Divider()
        Text("场景与摄像头状态和其他原生面板保持同步。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .textSelection(.enabled)
    .accessibilityIdentifier("native-device")
  }

  @ViewBuilder private var connectionActions: some View {
    if store.online {
      Button("待机", systemImage: "moon", action: store.sleep)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("native-device-sleep")
      Button("断开模拟设备", action: store.disconnect)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("native-device-disconnect")
    } else {
      Button(store.connection == .sleeping ? String(localized: "唤醒模拟设备") : String(localized: "连接模拟设备"), action: store.connect)
        .buttonStyle(.borderedProminent)
        .disabled(store.connection == .connecting)
        .accessibilityIdentifier("native-device-connect")
      if store.connection == .connecting {
        Button("取消连接", action: store.disconnect)
          .buttonStyle(.bordered)
          .accessibilityIdentifier("native-device-cancel")
      }
    }
  }

  private var cameraStatus: String {
    switch camera.phase {
    case .idle: String(localized: "已关闭")
    case .requestingPermission: String(localized: "等待摄像头授权")
    case .starting: String(localized: "正在开启摄像头…")
    case .running: String(localized: "正在使用摄像头")
    }
  }
}

private struct DeviceStatusRow: View {
  let title: LocalizedStringKey
  let value: String

  init(_ title: LocalizedStringKey, value: String) {
    self.title = title
    self.value = value
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: NativePageLayout.itemSpacing) {
        Text(title).foregroundStyle(.secondary).fixedSize()
        Spacer(minLength: NativePageLayout.itemSpacing)
        Text(value).fixedSize()
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(title).foregroundStyle(.secondary)
        Text(value).fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }
}
