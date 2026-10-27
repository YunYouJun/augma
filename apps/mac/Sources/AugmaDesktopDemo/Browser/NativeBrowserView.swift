import SwiftUI

struct NativeBrowserView: View {
  @ObservedObject var store: NativeBrowserStore
  let presentation: NativeBrowserPresentation
  @FocusState private var addressFocused: Bool

  init(store: NativeBrowserStore, presentation: NativeBrowserPresentation = .main) {
    self.store = store
    self.presentation = presentation
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        toolbarButton("后退", symbol: "chevron.left", action: store.goBack)
          .disabled(!store.canGoBack)
          .accessibilityIdentifier("native-browser-back")
        toolbarButton("前进", symbol: "chevron.right", action: store.goForward)
          .disabled(!store.canGoForward)
          .accessibilityIdentifier("native-browser-forward")
        Button(action: store.reloadOrStop) {
          Label(store.isLoading ? String(localized: "停止载入") : String(localized: "重新载入"),
                systemImage: store.isLoading ? "xmark" : "arrow.clockwise")
            .frame(width: 28, height: 28)
        }
        .disabled(!store.hasPage)
        .accessibilityIdentifier("native-browser-reload")

        TextField("输入网址或搜索", text: $store.addressInput)
          .textFieldStyle(.roundedBorder)
          .frame(minHeight: 28)
          .focused($addressFocused)
          .onSubmit(openAddress)
          .accessibilityIdentifier("native-browser-address")
        toolbarButton("打开网页", symbol: "arrow.right", action: openAddress)
          .disabled(store.addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("native-browser-go")
        Menu {
          Button("在默认浏览器中打开", systemImage: "arrow.up.right.square", action: store.openInDefaultBrowser)
            .disabled(store.currentURL == nil)
          Button("关闭网页", systemImage: "xmark", action: store.closePage)
            .disabled(!store.hasPage)
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

      if !store.title.isEmpty {
        Text(store.title)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
          .accessibilityIdentifier("native-browser-title")
      }

      if store.isLoading {
        ProgressView(value: store.progress)
          .progressViewStyle(.linear)
          .accessibilityLabel("网页载入进度")
      } else {
        Divider()
      }

      if let error = store.error {
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

      if store.hasPage, store.webView != nil {
        NativeBrowserWebView(store: store, presentation: presentation)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView {
          Label("沉浸式网页", systemImage: "globe")
        } description: {
          Text("输入网址，或使用 Bing 搜索。切换主窗口与沉浸模式时保留当前网页。")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("native-browser-empty")
      }
    }
    .controlSize(.regular)
    .background(.background)
    .onChange(of: store.addressFocusRequest) { _, _ in addressFocused = true }
    .onExitCommand { addressFocused = false }
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
