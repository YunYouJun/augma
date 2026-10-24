import SwiftUI

struct FocusTimerView: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands
  @State private var minutes = 25
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Form {
      Section {
        FocusTimerReadout(session: store.data.focus, large: true)
        FocusTimerControls(store: store, commands: commands)
        if store.data.focus == nil || store.data.focus?.status == .completed {
          Stepper(value: $minutes, in: 1...180) { Text(String(format: String(localized: "%lld 分钟"), minutes)) }
          Button("开始专注", systemImage: "play.fill") { commands.execute(.startFocus(Double(minutes) * 60)) }
            .buttonStyle(.borderedProminent).disabled(!store.writable)
        }
        Button("打开悬浮计时", systemImage: "pin") { openWindow(id: "focus-timer") }
        Text("关闭主窗口后继续计时；重新打开 App 时恢复。睡眠期间按实际经过时间计算。")
          .font(.callout).foregroundStyle(.secondary)
      }
      Section("到时通知") { FocusNotificationSettings(notifications: store.notifications) }
      Section {
        WorkspaceSaveStatus(store: store)
        WorkspaceResultView(commands: commands, store: store)
      }
      if !store.data.completions.isEmpty {
        Section("最近完成") {
          ForEach(store.data.completions.prefix(10)) { completion in
            LabeledContent(FocusTime.label(completion.duration)) {
              Text(completion.completedAt, format: .dateTime.month().day().hour().minute()).foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .formStyle(.grouped)
  }
}

struct FocusTimerReadout: View {
  let session: FocusSession?
  var large = false
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TimelineView(.periodic(from: .now, by: session?.status == .running && scenePhase != .background ? 1 : 3600)) { context in
      let remaining = session?.secondsRemaining(at: context.date) ?? 0
      VStack(spacing: large ? 14 : 6) {
        Text(status).font(large ? .headline : .caption).foregroundStyle(.secondary)
        Text(FocusTime.label(remaining))
          .font(.system(size: large ? 56 : 28, weight: .light, design: .rounded)).monospacedDigit()
          .contentTransition(.identity)
          .accessibilityLabel(String(localized: "剩余时间") + " " + FocusTime.label(remaining))
        if let session {
          ProgressView(value: min(1, max(0, 1 - remaining / session.duration)))
            .tint(.augmaAccent).accessibilityLabel("专注进度")
        }
      }
      .frame(maxWidth: .infinity).padding(.vertical, large ? 20 : 4)
    }
  }

  private var status: String {
    switch session?.status {
    case .running: String(localized: "专注中")
    case .paused: String(localized: "已暂停")
    case .completed: String(localized: "专注完成")
    case nil: String(localized: "准备开始")
    }
  }
}

struct FocusTimerControls: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands

  var body: some View {
    if let session = store.data.focus, session.status != .completed {
      HStack {
        Button(session.status == .running ? "暂停计时" : "继续计时", systemImage: session.status == .running ? "pause" : "play") {
          commands.execute(session.status == .running ? .pause : .resume)
        }
        Button("延长 5 分钟", systemImage: "plus") { commands.execute(.extend) }
          .disabled(!commands.isAvailable(.extend))
        Spacer()
        Button("结束计时", systemImage: "stop") { commands.execute(.cancel) }
      }
      .disabled(!store.writable)
    }
  }
}

struct FocusNotificationSettings: View {
  @ObservedObject var notifications: FocusNotifications
  var body: some View {
    if notifications.allowed {
      Label("到时通过系统通知提醒", systemImage: "bell.badge")
    } else {
      Button("开启到时通知", systemImage: "bell") { Task { await notifications.requestPermission() } }
      Text("通知未开启时，仍可在菜单栏和计时面板查看完成状态。")
        .font(.caption).foregroundStyle(.secondary)
    }
    if let message = notifications.message { Text(message).font(.caption).foregroundStyle(.secondary) }
  }
}

struct FloatingFocusView: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands
  var body: some View {
    VStack(spacing: 12) {
      FocusTimerReadout(session: store.data.focus)
      FocusTimerControls(store: store, commands: commands)
      if store.data.focus == nil || store.data.focus?.status == .completed {
        Button("专注 25 分钟") { commands.execute(.startFocus(1500)) }.disabled(!store.writable)
      }
      WorkspaceSaveStatus(store: store)
    }
    .padding(20).frame(width: 380)
    .background { DemoWindowLevelView(alwaysOnTop: true).frame(width: 0, height: 0) }
  }
}
