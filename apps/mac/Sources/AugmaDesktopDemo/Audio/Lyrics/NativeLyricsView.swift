import SwiftUI

struct NativeLyricsView: View {
  @ObservedObject var store: NativeLyricsStore
  let track: NativeNowPlayingTrack

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("歌词", systemImage: "text.alignleft").font(.callout.weight(.medium))
        Spacer()
        if case .available(let result) = store.state {
          Text(result.document.source.title).font(.caption).foregroundStyle(.secondary)
          if result.cached { Text("本地缓存").font(.caption).foregroundStyle(.secondary) }
        }
      }
      switch store.state {
      case .idle, .loading:
        ProgressView("正在获取歌词…").controlSize(.small)
      case .notFound:
        Text("暂无匹配的歌词。" ).font(.callout).foregroundStyle(.secondary)
      case .failed:
        HStack {
          Text("暂时无法获取歌词。" ).font(.callout).foregroundStyle(.secondary)
          Spacer()
          Button("重试") { store.retry(track) }
        }
      case .available(let result):
        if result.document.instrumental {
          Text("纯音乐，无歌词。").font(.callout).foregroundStyle(.secondary)
        } else if !result.document.lines.isEmpty {
          SyncedLyricsView(document: result.document, track: track)
        } else if let plain = result.document.plainText {
          ScrollView { Text(plain).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            .frame(maxHeight: 180)
          Text("此歌词没有时间轴。").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct SyncedLyricsView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let document: LyricsDocument
  let track: NativeNowPlayingTrack

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.25, paused: !track.playing)) { context in
      let active = track.elapsed(at: context.date).flatMap { document.activeLine(at: $0) }
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(Array(document.lines.enumerated()), id: \.offset) { index, line in
              VStack(alignment: .leading, spacing: 5) {
                Text(line.text.isEmpty ? " " : line.text)
                  .font(.body.weight(index == active ? .semibold : .regular))
                if let translation = line.translation {
                  Text(translation).font(.callout).foregroundStyle(.secondary)
                }
              }
              .foregroundStyle(index == active ? Color.primary : Color.secondary)
              .opacity(active == nil || index == active ? 1 : 0.65)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 12).padding(.vertical, 8)
              .background(index == active ? Color.accentColor.opacity(0.1) : .clear, in: .rect(cornerRadius: 10))
              .accessibilityElement(children: .combine)
              .accessibilityAddTraits(index == active ? .isSelected : [])
              .id(index)
            }
          }
          .padding(.vertical, 8)
        }
        .frame(height: 180)
        .accessibilityLabel("同步歌词")
        .onAppear { if let active { proxy.scrollTo(active, anchor: .center) } }
        .onChange(of: active) { _, index in
          guard let index else { proxy.scrollTo(0, anchor: .top); return }
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
        }
      }
    }
  }
}
