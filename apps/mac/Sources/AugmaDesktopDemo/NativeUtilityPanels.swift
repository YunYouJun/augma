import SwiftUI

struct NativeNotificationsView: View {
  @ObservedObject var store: NativeNotificationStore

  var body: some View {
    Form {
      Section("应用通知") {
        Text("记录本次窗口会话中的 Augma 操作，不会读取 macOS 通知中心。")
          .font(.callout).foregroundStyle(.secondary)
        Button("清空通知", systemImage: "trash", action: store.clear)
          .disabled(store.notices.isEmpty)
          .accessibilityIdentifier("native-notifications-clear")
      }
      if store.notices.isEmpty {
        ContentUnavailableView("暂无应用通知", systemImage: "bell", description: Text("扫描空间、切换场景或操作设备后，新的记录会出现在这里。"))
          .accessibilityIdentifier("native-notifications-empty")
      } else {
        Section {
          ForEach(store.notices) { notice in
            Label {
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                  Text(notice.title).font(.headline)
                  Spacer(minLength: 8)
                  Text(notice.date, style: .time)
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Text(notice.detail).font(.callout).foregroundStyle(.secondary)
              }
            } icon: {
              Image(systemName: notice.symbol).foregroundStyle(.tint)
            }
            .padding(.vertical, 4)
          }
        }
      }
    }
    .formStyle(.grouped)
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
    Form {
      Section("模拟设备") {
        HStack {
          Label(store.connection.title, systemImage: store.online ? "checkmark.circle" : "pause.circle")
            .accessibilityIdentifier("native-device-connection")
          if store.connection == .connecting { ProgressView().controlSize(.small) }
        }
        Text("此面板模拟 Augma 设备连接，不代表真实头显或蓝牙设备的连接状态。")
          .font(.callout).foregroundStyle(.secondary)
      }
      Section("当前状态") {
        LabeledContent("模拟场景", value: space.scene.title(locale: preferences.locale))
          .accessibilityIdentifier("native-device-scene")
        LabeledContent("当前地标", value: space.selected.title(locale: preferences.locale))
        LabeledContent("摄像头", value: cameraStatus)
          .accessibilityIdentifier("native-device-camera")
        LabeledContent("模拟扫描", value: space.scanning ? String(localized: "扫描中") : "\(Int(space.scanProgress))%")
        Text("场景与摄像头状态和其他原生面板保持同步。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        if store.online {
          Button("待机", systemImage: "moon", action: store.sleep)
            .accessibilityIdentifier("native-device-sleep")
          Button("断开模拟设备", action: store.disconnect)
            .accessibilityIdentifier("native-device-disconnect")
        } else {
          Button(store.connection == .sleeping ? String(localized: "唤醒模拟设备") : String(localized: "连接模拟设备"), action: store.connect)
            .buttonStyle(.borderedProminent)
            .disabled(store.connection == .connecting)
            .accessibilityIdentifier("native-device-connect")
          if store.connection == .connecting {
            Button("取消连接", action: store.disconnect)
              .accessibilityIdentifier("native-device-cancel")
          }
        }
      }
    }
    .formStyle(.grouped)
    .textSelection(.enabled)
    .accessibilityIdentifier("native-device")
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
