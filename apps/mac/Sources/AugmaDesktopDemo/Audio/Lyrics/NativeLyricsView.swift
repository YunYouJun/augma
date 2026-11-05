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
            .id(LyricsTrackIdentity(track))
        } else if let plain = result.document.plainText {
          GeometryReader { _ in
            ScrollView {
              Text(plain).frame(maxWidth: .infinity, alignment: .leading)
                .font(.body).lineSpacing(10)
                .textSelection(.enabled).padding(.vertical, 24)
            }
          }
            .frame(minHeight: 160, maxHeight: .infinity)
            .modifier(LyricsScrollStyle())
          Text("此歌词没有时间轴。").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
}

struct LyricsScrollStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .scrollIndicators(.hidden)
      .mask {
        VStack(spacing: 0) {
          LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
            .frame(height: 18)
          Rectangle().fill(.black)
          LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: 18)
        }
      }
  }
}
