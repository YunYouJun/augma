import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationDistrictSections: View {
  @ObservedObject var space: NativeSpaceStore
  @ObservedObject private var district: ApplicationDistrictStore
  @State private var confirmsRebuild = false
  @State private var name = ""

  init(space: NativeSpaceStore) {
    self.space = space
    district = space.applications
  }

  private var selected: ApplicationBuilding? {
    district.buildings.first { $0.id == space.selectedApplicationID } ?? district.buildings.first
  }

  var body: some View {
    Group {
      Section("应用大楼") {
        Button("添加应用…", systemImage: "plus.app", action: chooseApplications)
          .disabled(!district.writable)
          .accessibilityIdentifier("district-add-app")
        if district.buildings.isEmpty && district.loadError == nil {
          Text("把常用应用放进街区，点击大楼即可打开或切换。")
            .font(.callout).foregroundStyle(.secondary)
          ForEach(district.suggestions) { application in
            Button {
              if let id = district.add(url: URL(fileURLWithPath: application.path)) { space.selectedApplicationID = id }
            } label: { Label(application.name, systemImage: "plus") }
            .disabled(!district.writable)
            .accessibilityIdentifier("district-suggestion-" + application.id)
          }
        }
        ForEach(district.buildings.sorted { $0.slot < $1.slot }) { building in
          HStack(spacing: NativePageLayout.itemSpacing) {
            applicationIcon(building.id).frame(width: 32, height: 32)
            Button {
              space.selectedApplicationID = building.id
            } label: {
              VStack(alignment: .leading, spacing: 3) {
                Text(building.title).lineLimit(1)
                Label((district.states[building.id] ?? .stopped).title, systemImage: "circle.fill")
                  .font(.caption).foregroundStyle(statusColor(district.states[building.id] ?? .stopped))
              }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(building.title + "，" + (district.states[building.id] ?? .stopped).title)
            .accessibilityIdentifier("district-select-" + building.id)
            if building.fixed { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary) }
            Button {
              space.selectedApplicationID = building.id
              district.open(building.id)
            } label: { Image(systemName: "arrow.up.forward.app").frame(width: 28, height: 28) }
            .buttonStyle(.borderless)
            .help("打开或切换应用")
            .accessibilityLabel(Text("打开或切换应用") + Text("：" + building.title))
            .accessibilityIdentifier("district-open-" + building.id)
            .disabled(district.opening.contains(building.id))
          }
          .padding(.vertical, 4)
        }
        HStack(spacing: NativePageLayout.itemSpacing) {
          Text(String(format: String(localized: "%lld / 12 座大楼"), district.buildings.count))
            .font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button("刷新状态", systemImage: "arrow.clockwise", action: district.refresh)
            .labelStyle(.iconOnly)
        }
        if district.canUndoRemoval { Button("撤销移除", action: district.undoRemoval) }
      }
      if let selected {
        Section("应用管理") {
          Button("在 Craft Hub 查看卸载指引", systemImage: "arrow.up.forward.app") {
            district.openManagement(selected.id)
          }
          .accessibilityIdentifier("district-manage-app")
          Text("查看卸载入口与说明。Augma 仅传递应用标识，不会卸载或清理文件。")
            .font(.caption).foregroundStyle(.secondary)
        }
        Section("大楼布局") {
          VStack(alignment: .leading, spacing: 4) {
            Text("应用").font(.caption).foregroundStyle(.secondary)
            Text(selected.applicationName).fixedSize(horizontal: false, vertical: true)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("自定义名称（可留空）").font(.callout.weight(.medium))
            TextField("自定义名称（可留空）", text: $name)
              .labelsHidden().textFieldStyle(.roundedBorder)
              .accessibilityLabel("自定义名称（可留空）")
              .accessibilityIdentifier("district-building-name")
              .onSubmit { district.rename(selected.id, to: name) }
          }
          Button("保存名称") { district.rename(selected.id, to: name) }
            .disabled(!district.writable)
          Toggle("固定位置", isOn: Binding(get: { selected.fixed }, set: { district.setFixed(selected.id, $0) }))
            .disabled(!district.writable)
          Picker("位置", selection: Binding(get: { selected.slot }, set: { district.move(selected.id, to: $0) })) {
            ForEach(0..<ApplicationBuilding.capacity, id: \.self) { slot in
              Text(String(format: String(localized: "第 %lld 行 · 第 %lld 列"), slot / 4 + 1, slot % 4 + 1)).tag(slot)
            }
          }
          .disabled(selected.fixed || !district.writable)
          .accessibilityIdentifier("district-building-slot")
          Text("移动到已有大楼的位置会交换位置；固定的大楼不会被移动。")
            .font(.caption).foregroundStyle(.secondary)
          Button("重新排列未固定大楼", systemImage: "square.grid.3x3", action: district.restoreLayout)
            .disabled(!district.writable)
          Button("移除这座大楼", role: .destructive) { district.remove(selected.id) }
            .disabled(!district.writable)
            .accessibilityIdentifier("district-remove-app")
          Text("只移除空间入口，不会卸载应用。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      if let error = district.error {
        Section {
          Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
          Button("知道了", action: district.dismissError)
        }
      }
      Section("本机布局") {
        if let error = district.loadError {
          Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
          Button("重新读取布局", action: district.reload)
          Button("重新建立布局…") { confirmsRebuild = true }
        } else if let error = district.saveError {
          Label("布局尚未保存", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
          Text(error).font(.caption)
          Button("重试保存布局", action: district.retrySave)
        } else { Label("布局已保存在此 Mac", systemImage: "checkmark.circle").foregroundStyle(.secondary) }
        Text("主窗口与沉浸模式共享布局。运行状态来自 macOS，不读取应用内的文件或标签页。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .confirmationDialog("重新建立应用街区？", isPresented: $confirmsRebuild) {
      Button("备份原文件并重建", role: .destructive, action: district.rebuildUnreadableLayout)
    } message: { Text("无法读取的布局会先备份，再建立空白街区。") }
    .onAppear { district.refreshSuggestions(); syncName() }
    .onChange(of: selected?.id) { _, _ in syncName() }
    .onChange(of: selected?.nickname) { _, _ in syncName() }
  }

  private func syncName() { name = selected?.nickname ?? "" }

  private func chooseApplications() {
    let panel = NSOpenPanel()
    panel.title = String(localized: "选择要放入街区的应用")
    panel.allowedContentTypes = [.applicationBundle]
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = true
    panel.treatsFilePackagesAsDirectories = false
    panel.begin { response in
      guard response == .OK else { return }
      for url in panel.urls {
        if let id = district.add(url: url) { space.selectedApplicationID = id }
      }
    }
  }

  @ViewBuilder private func applicationIcon(_ id: String) -> some View {
    if let icon = district.icons[id] { Image(nsImage: icon).resizable().scaledToFit() }
    else { Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.secondary) }
  }

  private func statusColor(_ state: ApplicationRunState) -> Color {
    switch state {
    case .frontmost: .cyan
    case .running: .green
    case .missing: .orange
    case .stopped: .secondary
    }
  }
}
