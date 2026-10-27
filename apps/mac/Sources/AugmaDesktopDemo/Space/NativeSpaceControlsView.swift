import SwiftUI

/// A control-only surface suitable for the immersive inspector. A single Form
/// owns scrolling; the reusable sections also fit below a compact preview.
struct NativeSpaceControlsView: View {
  @ObservedObject var store: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore

  var body: some View {
    Form {
      NativeSpaceControlSections(store: store, preferences: preferences)
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .contentMargins(NativePageLayout.pagePadding, for: .scrollContent)
    .accessibilityIdentifier("native-space-controls")
  }
}

struct NativeSpaceControlSections: View {
  @ObservedObject var store: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore

  var body: some View {
    Group {
      sceneSection
      if store.sceneID == .workspace { ApplicationDistrictSections(space: store) }
      else if store.sceneID == .projects { ProjectRegionSections(space: store) }
      else {
        scanSection
        landmarkSection
        routeSection
      }
      displaySection
    }
  }

  private var sceneSection: some View {
    Section("空间场景") {
      Picker("场景", selection: Binding(get: { store.sceneID }, set: store.selectScene)) {
        Text("空中庭院").tag(NativeSpaceSceneID.garden)
        Text("城市漫游").tag(NativeSpaceSceneID.city)
        Text("应用街区").tag(NativeSpaceSceneID.workspace)
        Text("项目区域").tag(NativeSpaceSceneID.projects)
      }
      .accessibilityIdentifier("native-space-scene")
      Text(store.scene.detail(locale: preferences.locale))
        .font(.callout).foregroundStyle(.secondary)
    }
  }

  private var scanSection: some View {
    Section("模拟扫描") {
      HStack(spacing: NativePageLayout.itemSpacing) {
        Text(scanStatus)
        Spacer(minLength: 8)
        Text("\(Int(store.scanProgress))%")
          .monospacedDigit().foregroundStyle(.secondary)
      }
      ProgressView(value: store.scanProgress, total: 100)
        .accessibilityLabel(Text("模拟扫描进度"))
        .accessibilityValue(Text("\(Int(store.scanProgress))%"))
        .accessibilityIdentifier("native-space-scan-progress")
      Button(scanActionTitle, systemImage: store.scanning ? "stop.circle" : "viewfinder") {
        if store.scanning { store.cancelScan() } else { store.scan() }
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("native-space-scan")
      Text("扫描为模拟动画，不会使用摄像头或识别真实环境。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private var landmarkSection: some View {
    Section("地标与锚点") {
      Picker("当前地标", selection: Binding(get: { store.selectedID }, set: store.selectLandmark)) {
        ForEach(store.scene.landmarks) { landmark in
          Text(landmark.title(locale: preferences.locale)).tag(landmark.id)
        }
      }
      .accessibilityIdentifier("native-space-landmark")
      LabeledContent("模拟距离", value: "\(store.selected.distance) m")
      Text(store.selected.detail(locale: preferences.locale))
        .font(.callout).foregroundStyle(.secondary)

      if let pinned = store.scene.landmarks.first(where: { $0.id == store.pinnedLandmarkID }) {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text("已固定锚点")
              .font(.caption).foregroundStyle(.secondary)
            Text(pinned.title(locale: preferences.locale))
          }
        } icon: {
          Image(systemName: "pin.circle.fill").foregroundStyle(.tint)
        }
        .accessibilityIdentifier("native-space-pinned-anchor")
      } else {
        Label("尚未固定锚点", systemImage: "pin.slash")
          .foregroundStyle(.secondary)
      }
      Button(pinActionTitle, systemImage: store.pinnedLandmarkID == store.selectedID ? "pin.slash" : "pin") {
        store.togglePin()
      }
      .disabled(store.scanning || store.scanProgress < 100)
      .accessibilityIdentifier("native-space-pin")
      if store.scanProgress < 100 {
        Text("完成模拟扫描后，可以固定当前地标。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Text("地标和距离属于虚拟场景；真实地点请在「导航」中搜索。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private var routeSection: some View {
    Section("模拟路线") {
      if let step = store.routeStep {
        Text(routeInstruction(for: step))
          .font(.headline)
          .accessibilityIdentifier("native-space-route-instruction")
        ProgressView(value: store.routeProgress, total: 100)
          .accessibilityLabel(Text("模拟路线进度"))
          .accessibilityValue(Text("\(Int(store.routeProgress))%"))
        LabeledContent("剩余模拟距离", value: "\(store.remaining) m")
        ForEach(0..<5) { index in
          Label(routeStepTitle(index), systemImage: routeSymbol(at: index, current: step))
            .font(.callout)
            .foregroundStyle(index == step ? .primary : .secondary)
        }
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { routeActions(step: step) }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { routeActions(step: step) }
        }
      } else {
        Text("手动推进路线，预览通往当前地标的虚拟路径。")
          .font(.callout).foregroundStyle(.secondary)
        Button("开始模拟路线", systemImage: "location", action: store.startRoute)
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("native-space-route-start")
      }
    }
  }

  private var displaySection: some View {
    Section("空间显示") {
      HStack(spacing: NativePageLayout.itemSpacing) {
        Button("缩小", systemImage: "minus.magnifyingglass") {
          store.setView(yaw: store.viewYaw, pitch: store.viewPitch, scale: store.viewScale / 1.15)
        }
        .disabled(store.viewScale <= 0.65)
        .accessibilityIdentifier("native-space-zoom-out")
        Button("放大", systemImage: "plus.magnifyingglass") {
          store.setView(yaw: store.viewYaw, pitch: store.viewPitch, scale: store.viewScale * 1.15)
        }
        .disabled(store.viewScale >= 1.6)
        .accessibilityIdentifier("native-space-zoom-in")
      }
      Button("重置视角", systemImage: "arrow.counterclockwise", action: store.resetView)
        .accessibilityIdentifier("native-space-reset-view")
      Text("拖动旋转 · 滚动缩放")
        .font(.caption).foregroundStyle(.secondary)
      Toggle("显示 HUD", isOn: preferences.binding(\.showHud))
        .accessibilityIdentifier("native-space-hud")
    }
  }

  @ViewBuilder private func routeActions(step: Int) -> some View {
    Button(step >= 4 ? String(localized: "重新开始模拟路线") : String(localized: "前进一步"), systemImage: step >= 4 ? "arrow.clockwise" : "location") {
      if step >= 4 { store.startRoute() } else { store.advanceRoute() }
    }
    .buttonStyle(.borderedProminent)
    .accessibilityIdentifier("native-space-route-advance")
    Button("结束模拟路线", action: store.cancelRoute)
      .accessibilityIdentifier("native-space-route-end")
  }

  private var scanStatus: String {
    if store.scanning { return String(localized: "正在模拟扫描…") }
    return store.scanProgress >= 100 ? String(localized: "模拟扫描已完成") : String(localized: "等待模拟扫描")
  }

  private var scanActionTitle: String {
    if store.scanning { return String(localized: "取消模拟扫描") }
    return store.scanProgress >= 100 ? String(localized: "重新模拟扫描") : String(localized: "开始模拟扫描")
  }

  private var pinActionTitle: String {
    if store.pinnedLandmarkID == store.selectedID { return String(localized: "取消固定当前地标") }
    return store.pinnedLandmarkID == nil ? String(localized: "固定当前地标") : String(localized: "将当前地标设为锚点")
  }

  private func routeStepTitle(_ step: Int) -> String {
    switch step {
    case 0: String(localized: "当前位置")
    case 1: String(localized: "前方步道")
    case 2: String(localized: "转角路口")
    case 3: String(localized: "目标锚点")
    default: store.selected.title(locale: preferences.locale)
    }
  }

  private func routeInstruction(for step: Int) -> String {
    switch step {
    case 0: String(localized: "沿前方步道出发")
    case 1: String(localized: "继续前往转角路口")
    case 2: String(localized: "转向目标锚点")
    case 3: String(localized: "前往目的地")
    default: String(localized: "已到达模拟目的地")
    }
  }

  private func routeSymbol(at index: Int, current: Int) -> String {
    index < current ? "checkmark.circle.fill" : index == current ? "location.circle.fill" : "circle"
  }
}
