import AppKit
import SwiftUI

struct ApplicationLibraryView: View {
  @ObservedObject var store: ApplicationLibraryStore
  @ObservedObject var dock: NativeDockStore
  let section: ApplicationLibrarySection
  @State private var localQuery = ""

  var body: some View {
    Group {
      if section == .store {
        ApplicationStoreSearchView(store: store, dock: dock)
      } else {
        NativePage {
          HStack {
            TextField("搜索名称或 Bundle ID", text: $localQuery)
              .textFieldStyle(.roundedBorder)
              .accessibilityIdentifier("application-library-search")
            refreshButton
          }
          Text("查看本机应用，打开应用或将其固定到 Augma Dock。")
            .font(.callout).foregroundStyle(.secondary)
          if store.isLoading { ProgressView("正在读取应用列表…").controlSize(.small) }
          if !store.localError.isEmpty { errorText(store.localError) }
          if !store.actionError.isEmpty { errorText(store.actionError) }
          let applications = store.filteredApplications(localQuery)
          if applications.isEmpty && !store.isLoading {
            ContentUnavailableView("没有找到应用", systemImage: "magnifyingglass",
              description: Text("试试其他名称，或安装应用后刷新列表。"))
          }
          LazyVStack(spacing: 10) {
            ForEach(applications) { app in
              InstalledApplicationRow(application: app, store: store, dock: dock)
            }
          }
        }
      }
    }
    .task { await store.refresh() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      Task { await store.refresh() }
    }
  }

  private var refreshButton: some View {
    Button("刷新", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
      .labelStyle(.iconOnly).disabled(store.isLoading).help("刷新已安装应用")
      .accessibilityIdentifier("application-library-refresh")
  }

  private func errorText(_ error: String) -> some View { Text(error).font(.callout).foregroundStyle(.red) }
}

private struct InstalledApplicationRow: View {
  let application: InstalledApplication
  @ObservedObject var store: ApplicationLibraryStore
  @ObservedObject var dock: NativeDockStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
          .resizable().scaledToFit().frame(width: 42, height: 42).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text(application.name).font(.headline).lineLimit(1)
          Text(application.id).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer(minLength: 0)
      }
      HStack {
        Button("打开", systemImage: "arrow.up.forward.app") { Task { await dock.open(.application(application)) } }
        Spacer(minLength: 8)
        Button(dock.contains(application) ? "已加入 Dock" : "加入 Dock",
               systemImage: dock.contains(application) ? "checkmark" : "plus") {
          store.addToDock(application, dock: dock)
        }
        .disabled(dock.contains(application))
        .help("加入 Dock")
        .accessibilityIdentifier("application-pin-" + application.id)
      }
    }
    .nativeCard()
    .contextMenu {
      Button("在访达中显示", systemImage: "folder") {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: application.path)])
      }
      if dock.contains(application) {
        Button("从 Dock 中移除", systemImage: "minus.circle") { dock.remove(.application(application)) }
      }
    }
  }
}

private struct ApplicationStoreSearchView: View {
  @ObservedObject var store: ApplicationLibraryStore
  @ObservedObject var dock: NativeDockStore
  @State private var query = ""
  @State private var submittedQuery = ""
  @State private var requestID = UUID()

  var body: some View {
    NativePage {
      HStack {
        TextField("搜索 Mac App Store", text: $query).textFieldStyle(.roundedBorder)
          .onSubmit(submit).accessibilityIdentifier("application-store-search")
        Button("搜索", systemImage: "magnifyingglass", action: submit)
          .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      Text("在 App Store 完成购买和安装；返回后刷新，即可加入 Dock。")
        .font(.callout).foregroundStyle(.secondary)
      Button("刷新已安装应用", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
        .disabled(store.isLoading)
      if store.isSearching { ProgressView("正在查询 App Store…").controlSize(.small) }
      if !store.searchError.isEmpty { Text(store.searchError).font(.callout).foregroundStyle(.red) }
      if !store.actionError.isEmpty { Text(store.actionError).font(.callout).foregroundStyle(.red) }
      if !store.isSearching && store.results.isEmpty && store.searchError.isEmpty {
        ContentUnavailableView(store.hasSearched ? "没有找到应用" : "发现 Mac 应用", systemImage: "app.badge",
          description: Text(store.hasSearched ? "试试其他名称，或安装应用后刷新列表。" : "输入应用名称，搜索 Mac App Store。"))
      }
      LazyVStack(spacing: 10) {
        ForEach(store.results) { app in
          StoreApplicationRow(application: app, store: store, dock: dock)
        }
      }
    }
    .task(id: requestID) { await store.search(submittedQuery) }
    .onChange(of: query) { _, _ in
      submittedQuery = ""; requestID = UUID(); store.clearSearch()
    }
  }

  private func submit() { submittedQuery = query; requestID = UUID() }
}

private struct StoreApplicationRow: View {
  let application: StoreApplication
  @ObservedObject var store: ApplicationLibraryStore
  @ObservedObject var dock: NativeDockStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        AsyncImage(url: application.iconURL) { image in image.resizable().scaledToFit() } placeholder: {
          Image(systemName: "app").font(.title).foregroundStyle(.secondary)
        }
        .frame(width: 42, height: 42).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text(application.name).font(.headline).lineLimit(2)
          Text(application.developer).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          if !application.price.isEmpty { Text(application.price).font(.caption).foregroundStyle(.secondary) }
        }
        Spacer(minLength: 0)
      }
      ViewThatFits(in: .horizontal) {
        HStack { storeButton; Spacer(minLength: 8); pinButton }
        VStack(alignment: .leading, spacing: 8) { storeButton; pinButton }
      }
    }
    .nativeCard()
  }

  private var storeButton: some View {
    Button("在 App Store 查看", systemImage: "arrow.up.right") { store.openStore(application) }
  }

  @ViewBuilder private var pinButton: some View {
    if let installed = store.installedApplication(bundleID: application.bundleID) {
      Button(dock.contains(installed) ? "已加入 Dock" : "加入 Dock",
             systemImage: dock.contains(installed) ? "checkmark" : "plus") {
        store.addToDock(installed, dock: dock)
      }.disabled(dock.contains(installed))
        .help("加入 Dock")
    }
  }
}
