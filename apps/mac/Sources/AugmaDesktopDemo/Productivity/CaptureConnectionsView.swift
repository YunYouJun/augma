import SwiftUI

struct CaptureConnectionsView: View {
  @ObservedObject var captures: QuickCaptureStore

  var body: some View {
    MicrosoftConnectionForm(store: captures.microsoft, sending: !captures.active.isEmpty) {
      captures.openDestination(.appleNotes)
    }
  }
}

private struct MicrosoftConnectionForm: View {
  @ObservedObject var store: MicrosoftToDoStore
  let sending: Bool
  let openNotes: () -> Void
  @State private var clientID = ""

  var body: some View {
    Form {
      Section("macOS 备忘录") {
        Text("笔记保存到备忘录的默认账户和默认文件夹。首次发送时，macOS 会请求自动化权限。")
          .font(.callout).foregroundStyle(.secondary)
        Button("打开备忘录", action: openNotes)
      }
      Section("Microsoft To Do") {
        Text(store.connected ? "已连接 Microsoft To Do" : "连接后，可将待办添加到所选清单。")
        if store.connected {
          VStack(alignment: .leading, spacing: 8) {
            Text("待办清单").font(.callout.weight(.medium))
            Picker("待办清单", selection: $store.selectedListID) {
              if !store.lists.contains(where: { $0.id == store.selectedListID }) {
                Text("请刷新并选择清单").tag(store.selectedListID)
              }
              ForEach(store.lists) { list in Text(list.displayName).tag(list.id) }
            }
            .labelsHidden().accessibilityLabel("待办清单")
            .frame(maxWidth: .infinity)
          }
          HStack(spacing: NativePageLayout.itemSpacing) {
            Button("刷新清单") { Task { await store.refreshLists() } }
            Button("断开连接") { store.disconnect() }
          }
          .disabled(store.busy || sending)
        } else {
          Button("连接 Microsoft To Do") { store.signIn() }
            .disabled(!store.configured || store.busy || sending)
          if !store.configured {
            Text("此版本尚未配置 Microsoft 登录，请联系 Augma 维护者或在连接设置中配置应用 ID。")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        if store.busy {
          HStack {
            ProgressView().controlSize(.small)
            Text("正在连接…")
            if !store.connected { Button("取消登录") { store.cancelSignIn() } }
          }
        }
        if let error = store.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
        Text("登录凭据保存在 macOS 钥匙串。仅在你发送待办时上传记录内容。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        DisclosureGroup("自定义 Microsoft 应用（高级）") {
          Text("通常只需登录 Microsoft；仅自建或调试应用时需要填写应用 ID。")
            .font(.caption).foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 8) {
            Text("Microsoft Application（Client）ID").font(.callout.weight(.medium))
            TextField("Microsoft Application（Client）ID", text: $clientID)
              .labelsHidden().textFieldStyle(.roundedBorder)
              .accessibilityLabel("Microsoft Application（Client）ID")
          }
          ViewThatFits(in: .horizontal) {
            HStack(spacing: NativePageLayout.itemSpacing) { applicationIDActions }
              .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
              applicationIDActions
            }
          }
          .disabled(store.busy || store.connected || sending)
          Text("在 Microsoft Entra 注册支持个人及组织账户的应用，添加 iOS / macOS 平台和下方回调地址，并授予 Tasks.ReadWrite 委托权限。不需要 Client Secret。")
            .font(.caption).foregroundStyle(.secondary)
          Text(MicrosoftOAuthRequest.redirectURI).font(.caption.monospaced()).textSelection(.enabled)
          Link("Microsoft 应用注册", destination: URL(string: "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!)
        }
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .onAppear { clientID = store.clientID }
  }

  @ViewBuilder private var applicationIDActions: some View {
    Button("保存应用 ID") { store.configure(clientID: clientID) }
    if store.canUseBundledClientID {
      Button("使用 Augma 默认配置") { store.useBundledClientID(); clientID = store.clientID }
    }
  }
}

struct CaptureFeedbackView: View {
  @ObservedObject var captures: QuickCaptureStore
  var body: some View {
    if let message = captures.message {
      HStack(alignment: .firstTextBaseline, spacing: NativePageLayout.itemSpacing) {
        Text(message).font(.callout).textSelection(.enabled)
        Spacer()
        if let receipt = captures.receipt {
          Button("打开") { captures.openDestination(receipt.destination) }
            .fixedSize(horizontal: true, vertical: false)
        }
      }
    }
  }
}

struct CaptureDeliveryControls: View {
  let note: QuickNote
  @ObservedObject var captures: QuickCaptureStore
  @State private var confirmingRetry = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let delivery = note.delivery {
        Text(delivery.destination.title).font(.caption).foregroundStyle(.secondary)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { deliveryActions(delivery) }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: 8) { deliveryActions(delivery) }
        }
        if let error = delivery.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
      } else {
        HStack(spacing: NativePageLayout.itemSpacing) {
          Text("历史本地记录").font(.caption).foregroundStyle(.secondary)
          Menu("转存到") {
            ForEach(CaptureDestination.allCases, id: \.self) { target in
              Button(target.title) { captures.send(note.id, destination: target) }
            }
          }
        }
      }
    }
    .controlSize(.small)
    .disabled(captures.active.contains(note.id))
    .confirmationDialog("确认目标应用中没有这条记录？", isPresented: $confirmingRetry) {
      Button("确认未创建，重新发送") { captures.send(note.id, confirmedAbsent: true) }
      Button("取消", role: .cancel) {}
    } message: {
      Text("上次发送可能已经成功。请先检查备忘录或 To Do，重复发送会创建另一条记录。")
    }
  }

  @ViewBuilder private func deliveryActions(_ delivery: CaptureDelivery) -> some View {
    if delivery.status == .sending {
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        Text("正在发送…").font(.caption)
      }
    } else if delivery.status == .uncertain {
      Button("检查目标应用") { captures.openDestination(delivery.destination) }
      Button("确认未创建后重试") { confirmingRetry = true }
    } else {
      Button("重试发送") { captures.send(note.id) }
      Menu("改用当前目标重试") {
        ForEach(CaptureDestination.allCases, id: \.self) { target in
          Button(target.title) { captures.retargetAndSend(note.id, destination: target) }
        }
      }
    }
  }
}
