import SwiftUI

struct NativePlaybackQueueView: View {
  @ObservedObject var store: NativePlaybackQueueStore

  var body: some View {
    // Keep observation attached to a stable container as loading becomes content.
    VStack(alignment: .leading, spacing: 0) {
      switch store.state {
      case .idle, .loading:
        ProgressView("正在读取播放队列…").frame(maxWidth: .infinity, minHeight: 240)
      case .unavailable:
        ContentUnavailableView {
          Label("暂时无法读取播放队列", systemImage: "list.bullet")
        } description: {
          Text("请在网易云音乐中打开播放列表后重试。")
        } actions: {
          Button("重新读取") { store.refresh() }
        }
        .frame(height: 240)
      case .available(let queue):
        content(queue)
      }
    }
    .onAppear { store.startObserving() }
    .onDisappear { store.stopObserving() }
  }

  private func content(_ queue: NativePlaybackQueue) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        if queue.items.isEmpty {
          Text("网易云音乐的播放队列为空。").foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
          LazyVStack(spacing: 4) {
            ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
              row(item, number: index + 1).id(item.id)
            }
          }
        }
      }
      .accessibilityLabel("当前播放队列")
      // The native edge effect follows bars in the scroll view's safe area.
      // Separate siblings do not create a softened boundary inside this card.
      .safeAreaBar(edge: .top, spacing: 12) {
        HStack {
          Label("当前播放队列", systemImage: "list.bullet").font(.callout.weight(.medium))
          Text("\(queue.items.count) 首").font(.caption).monospacedDigit().foregroundStyle(.secondary)
          Spacer()
          if let id = store.currentItemID {
            Button("定位当前曲") { proxy.scrollTo(id, anchor: .center) }.buttonStyle(.borderless)
          }
        }
      }
      .safeAreaBar(edge: .bottom, alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          if !queue.items.isEmpty, store.currentItemID == nil {
            Text("未能唯一匹配当前歌曲。").font(.caption).foregroundStyle(.secondary)
          }
          Text("队列仅供查看，播放顺序由网易云音乐管理。").font(.caption).foregroundStyle(.secondary)
        }
      }
      .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
      .frame(minHeight: 200, maxHeight: .infinity)
      .onAppear { if let id = store.currentItemID { proxy.scrollTo(id, anchor: .center) } }
      .onChange(of: store.currentItemID) { _, id in
        if let id { proxy.scrollTo(id, anchor: .center) }
      }
    }
  }

  private func row(_ item: NativePlaybackQueueItem, number: Int) -> some View {
    let active = item.id == store.currentItemID
    return HStack(spacing: 12) {
      Group {
        if active { Image(systemName: store.playing ? "waveform" : "pause.fill") }
        else { Text(number.formatted()).monospacedDigit() }
      }
      .font(.caption).foregroundStyle(.secondary).frame(width: 26)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.track.name).font(.callout.weight(active ? .semibold : .regular)).lineLimit(1)
        Text(item.track.artists.map(\.name).joined(separator: " / "))
          .font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer(minLength: 8)
      if let milliseconds = item.track.duration, milliseconds.isFinite, milliseconds > 0, milliseconds < 604_800_000 {
        let seconds = Int(milliseconds / 1000)
        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
          .font(.caption).monospacedDigit().foregroundStyle(.secondary)
      }
    }
    .foregroundStyle(active ? Color.accentColor : Color.primary)
    .padding(.horizontal, 10).padding(.vertical, 8)
    .background(active ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(active ? .isSelected : [])
  }
}
