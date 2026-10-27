import AppKit
import SwiftUI

struct NativeCameraView: View {
  @ObservedObject var store: NativeCameraStore
  @State private var consumer = UUID()

  var body: some View {
    NativePage {
      NativePageSection("摄像头") {
        ZStack {
          if store.running {
            NativeCameraPreview(session: store.previewSession, mirrored: store.mirrored)
              .accessibilityLabel(Text("摄像头实时预览"))
          } else {
            ContentUnavailableView {
              Label("摄像头", systemImage: "camera")
            } description: {
              Text(store.busy ? String(localized: "正在准备摄像头…") : String(localized: "点击开启摄像头以查看实时画面。"))
            }
          }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(minHeight: 160, maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: NativePageLayout.cornerRadius))

        if !store.devices.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("摄像头设备").font(.callout.weight(.medium))
            Picker("摄像头设备", selection: Binding(get: { store.selectedDeviceID ?? "" }, set: store.selectDevice)) {
              ForEach(store.devices) { device in Text(device.name).tag(device.id) }
            }
            .labelsHidden()
            .disabled(store.takingPhoto)
          }
        }
        Toggle("镜像预览", isOn: $store.mirrored)
          .toggleStyle(.switch)
        cameraStatus
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { cameraActions }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { cameraActions }
        }
        .controlSize(.large)

        if let error = store.error {
          Label(error.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
          if error == .denied || error == .restricted {
            Button("打开摄像头隐私设置", action: store.openPrivacySettings)
          } else if !store.running {
            Button("重新检测摄像头") { Task { await store.refreshDevices() } }
          }
        }
      }
      if let data = store.photoData, let image = NSImage(data: data) {
        NativePageSection("最近拍摄") {
          Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 160)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("最近拍摄的照片"))
          ViewThatFits(in: .horizontal) {
            HStack(spacing: NativePageLayout.itemSpacing) { photoActions }
              .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { photoActions }
          }
          if let name = store.savedPhotoName { Text(name).font(.caption).foregroundStyle(.secondary) }
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("离开摄像头页面、切换到其他应用或 Mac 进入睡眠后，摄像头会自动关闭。返回后请手动开启。")
          .font(.caption).foregroundStyle(.secondary)
        Text("照片仅在点击保存后写入所选位置。镜像仅影响预览，照片保持原始方向。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .background(NativeCameraVisibilityProbe(store: store, consumer: consumer).frame(width: 0, height: 0))
    .task { await store.refreshDevices() }
    .onDisappear { store.setConsumerVisible(consumer, false) }
  }

  private var cameraStatus: some View {
    HStack(spacing: 8) {
      if store.running {
        Label("摄像头正在使用", systemImage: "circle.fill").foregroundStyle(Color.augmaHealthy)
      } else if store.busy {
        ProgressView().controlSize(.small)
        Text("正在准备摄像头…").foregroundStyle(.secondary)
      } else {
        Label("摄像头已关闭", systemImage: "camera.fill").foregroundStyle(.secondary)
      }
    }
    .font(.callout)
  }

  @ViewBuilder private var cameraActions: some View {
    Button(store.running || store.busy ? String(localized: "关闭摄像头") : String(localized: "开启摄像头")) {
      if store.running || store.busy { store.stop() } else { store.start() }
    }
    .buttonStyle(.borderedProminent)
    Button("拍照", systemImage: "camera.aperture", action: store.capturePhoto)
      .disabled(!store.running || store.takingPhoto || store.savingPhoto)
  }

  @ViewBuilder private var photoActions: some View {
    Button("保存照片…", systemImage: "square.and.arrow.down", action: store.savePhoto)
      .disabled(store.savingPhoto)
    Button("丢弃照片", action: store.discardPhoto).disabled(store.savingPhoto)
  }
}
