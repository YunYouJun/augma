import SwiftUI

struct NativeBrowserView: View {
  @ObservedObject var store: NativeBrowserStore
  let presentation: NativeBrowserPresentation

  init(store: NativeBrowserStore, presentation: NativeBrowserPresentation = .main) {
    self.store = store
    self.presentation = presentation
  }

  var body: some View {
    VStack(spacing: 0) {
      NativeBrowserTabStrip(store: store)
      Divider()
      NativeBrowserPageView(store: store, tab: store.activeTab, presentation: presentation)
        .id(store.activeTabID)
    }
    .controlSize(.regular)
    .background(.background)
  }
}

private struct NativeBrowserTabStrip: View {
  @ObservedObject var store: NativeBrowserStore

  var body: some View {
    HStack(spacing: 8) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(store.tabs) { tab in
              NativeBrowserTabChip(store: store, tab: tab)
                .id(tab.id)
            }
          }
          .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .onChange(of: store.activeTabID) { _, id in
          withAnimation(.easeOut(duration: 0.16)) { proxy.scrollTo(id, anchor: .center) }
        }
        .onAppear { proxy.scrollTo(store.activeTabID, anchor: .center) }
      }

      Button { store.newTab() } label: {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .semibold))
          .frame(width: 26, height: 26)
      }
      .buttonStyle(.borderless)
      .help("新建标签页")
      .accessibilityLabel("新建标签页")
      .accessibilityIdentifier("native-browser-new-tab")
    }
    .padding(.horizontal, NativePageLayout.itemSpacing)
    .padding(.top, 10)
    .padding(.bottom, 6)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("标签页")
  }
}

private struct NativeBrowserTabChip: View {
  @ObservedObject var store: NativeBrowserStore
  @ObservedObject var tab: NativeBrowserTab
  @State private var hovering = false

  private var isActive: Bool { store.activeTabID == tab.id }

  var body: some View {
    HStack(spacing: 4) {
      Button { store.selectTab(tab.id) } label: {
        HStack(spacing: 5) {
          if tab.isLoading {
            ProgressView()
              .controlSize(.mini)
              .frame(width: 14)
          } else {
            Image(systemName: "globe")
              .font(.system(size: 10))
              .frame(width: 14)
          }
          Text(tab.displayTitle)
            .font(.caption)
            .foregroundStyle(isActive ? .primary : .secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(minWidth: 56, maxWidth: 150, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help(tab.displayTitle)
      .accessibilityLabel(tab.displayTitle)
      .accessibilityIdentifier("native-browser-tab-" + tab.id.uuidString)

      Button { store.closeTab(tab.id) } label: {
        Image(systemName: "xmark")
          .font(.system(size: 8, weight: .bold))
          .frame(width: 16, height: 16)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .opacity(hovering || isActive ? 0.8 : 0.35)
      .help("关闭标签页")
      .accessibilityLabel("关闭标签页")
      .accessibilityIdentifier("native-browser-tab-close-" + tab.id.uuidString)
    }
    .padding(.leading, 9)
    .padding(.trailing, 4)
    .frame(height: 26)
    .background(isActive ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 7))
    .overlay {
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: 1)
    }
    .onHover { hovering = $0 }
    .contextMenu {
      Button("新建标签页", systemImage: "plus") { store.newTab() }
      Button("关闭标签页", systemImage: "xmark") { store.closeTab(tab.id) }
        .disabled(store.tabs.count == 1 && !tab.hasPage)
      Button("在默认浏览器中打开", systemImage: "arrow.up.right.square") { tab.openInDefaultBrowser() }
        .disabled(tab.currentURL == nil)
    }
    .accessibilityElement(children: .contain)
  }
}

private struct NativeBrowserPageView: View {
  @ObservedObject var store: NativeBrowserStore
  @ObservedObject var tab: NativeBrowserTab
  let presentation: NativeBrowserPresentation
  @FocusState private var addressFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      toolbar

      if tab.isLoading {
        ProgressView(value: tab.progress)
          .progressViewStyle(.linear)
          .accessibilityLabel("网页载入进度")
      } else {
        Divider()
      }

      if let error = tab.error {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle")
          Text(error).font(.callout).textSelection(.enabled)
          Spacer()
          Button("关闭提示", systemImage: "xmark", action: store.dismissError).labelStyle(.iconOnly)
        }
        .padding(12)
        .background(.orange.opacity(0.10))
        .accessibilityIdentifier("native-browser-error")
      }

      if tab.hasPage, tab.webView != nil {
        NativeBrowserWebView(store: store, tab: tab, presentation: presentation)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView {
          Label("沉浸式网页", systemImage: "globe")
        } description: {
          Text("输入网址，或使用 Bing 搜索。⌘T 新建标签页；切换主窗口与沉浸模式时保留所有标签页。")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("native-browser-empty")
      }
    }
    .onChange(of: store.addressFocusRequest) { _, _ in addressFocused = true }
    .onAppear { if !tab.hasPage { addressFocused = true } }
    .onExitCommand { addressFocused = false }
  }

  private var toolbar: some View {
    HStack(spacing: 8) {
      toolbarButton("后退", symbol: "chevron.left", action: store.goBack)
        .disabled(!tab.canGoBack)
        .accessibilityIdentifier("native-browser-back")
      toolbarButton("前进", symbol: "chevron.right", action: store.goForward)
        .disabled(!tab.canGoForward)
        .accessibilityIdentifier("native-browser-forward")
      Button(action: store.reloadOrStop) {
        Label(tab.isLoading ? String(appLocalized: "停止载入") : String(appLocalized: "重新载入"),
              systemImage: tab.isLoading ? "xmark" : "arrow.clockwise")
          .frame(width: 28, height: 28)
      }
      .disabled(!tab.hasPage)
      .accessibilityIdentifier("native-browser-reload")

      TextField("输入网址或搜索", text: $tab.addressInput)
        .textFieldStyle(.roundedBorder)
        .frame(minHeight: 28)
        .focused($addressFocused)
        .onSubmit(openAddress)
        .accessibilityIdentifier("native-browser-address")
      toolbarButton("打开网页", symbol: "arrow.right", action: openAddress)
        .disabled(tab.addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("native-browser-go")
      Menu {
        Button("Safari", systemImage: "safari") { store.openExternally(in: .safari) }
          .disabled(!NativeBrowserExternalTarget.safari.isAvailable)
        Button("Google Chrome", systemImage: "globe") { store.openExternally(in: .chrome) }
          .disabled(!NativeBrowserExternalTarget.chrome.isAvailable)
      } label: {
        Label("在默认浏览器中打开", systemImage: "arrow.up.forward.app")
          .labelStyle(.iconOnly)
          .frame(width: 28, height: 28)
      } primaryAction: {
        store.openInDefaultBrowser()
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.visible)
      .fixedSize()
      .help("在默认浏览器中打开")
      .accessibilityIdentifier("native-browser-open-external")
      .disabled(tab.currentURL == nil)
      Menu {
        Button("新建标签页", systemImage: "plus") { store.newTab() }
        Button("在默认浏览器中打开", systemImage: "arrow.up.right.square", action: store.openInDefaultBrowser)
          .disabled(tab.currentURL == nil)
        Button("关闭标签页", systemImage: "xmark", action: store.closeActiveTab)
          .disabled(!store.canCloseTab)
      } label: {
        Label("网页选项", systemImage: "ellipsis.circle")
          .frame(width: 28, height: 28)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityIdentifier("native-browser-menu")
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .padding(NativePageLayout.itemSpacing)
  }

  private func toolbarButton(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(title, systemImage: symbol).frame(width: 28, height: 28)
    }
    .help(Text(title))
  }

  private func openAddress() {
    store.submitAddress()
    addressFocused = false
  }
}
