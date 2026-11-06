import SwiftUI

struct NativeAudioView: View {
  @ObservedObject var store: NativeAudioStore
  @State private var queuePresented = false

  var body: some View {
    Group {
      if case .track(let track) = store.status {
        GeometryReader { geometry in
          let wide = geometry.size.width >= 800
          // One stable page fills the viewport and only overflows in short windows.
          ScrollView {
            playerPage(track, wide: wide)
              .frame(minHeight: geometry.size.height, alignment: .top)
          }
          .scrollBounceBehavior(.basedOnSize)
        }
      } else {
        statusPage
      }
    }
    .controlSize(.regular)
    .onAppear { store.startObserving() }
  }

  private func playerPage(_ track: NativeNowPlayingTrack, wide: Bool) -> some View {
    NativePageSection("正在播放") {
      NativeNowPlayingContent(track: track, lyrics: store.lyrics, store: store, queuePresented: $queuePresented, wide: wide)
    }
    .nativePageContent(maxWidth: NativePageLayout.wideContentWidth)
  }

  private var statusPage: some View {
    NativePage {
      NativePageSection("正在播放") {
        switch store.status {
        case .track: EmptyView()
        case .loading:
          ProgressView("正在读取网易云音乐…")
            .frame(maxWidth: .infinity, minHeight: 160)
        case .notRunning:
          ContentUnavailableView("网易云音乐未运行", systemImage: "music.note",
            description: Text("在网易云音乐中播放歌曲后，这里会显示当前播放信息。"))
        case .idle:
          ContentUnavailableView("当前没有正在播放的音乐", systemImage: "music.note",
            description: Text("暂未读取到网易云音乐的当前播放信息。"))
        case .unavailable:
          ContentUnavailableView {
            Label("暂时无法读取播放信息", systemImage: "waveform.slash")
          } description: {
            Text("请确认网易云音乐正在运行后重试。")
          } actions: {
            Button("重新读取") { store.refresh() }
          }
        }
      }
      Text("读取本机播放信息，支持网易云音乐播放、暂停、切歌和进度调整，联网获取歌词并缓存在本机。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}

private struct NativeNowPlayingContent: View {
  let track: NativeNowPlayingTrack
  let lyrics: NativeLyricsStore
  @ObservedObject var store: NativeAudioStore
  @Binding var queuePresented: Bool
  let wide: Bool

  var body: some View {
    // Preserve the lyric/queue view identity when the window changes width.
    let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 28))
      : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
    layout {
      playback.frame(width: wide ? 320 : nil)
      Divider()
      detail
    }
    .textSelection(.enabled)
  }

  private var playback: some View {
    VStack(alignment: .leading, spacing: 16) {
      NativeNowPlayingHeaderLayout { artwork; metadata }
      if let error = store.playbackError {
        Label(error, systemImage: "exclamationmark.circle")
          .font(.caption).foregroundStyle(.secondary)
      }
      NativePlaybackPositionView(track: track, store: store)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var detail: some View {
    Group {
      if queuePresented {
        // Bound the inner scroll view so its queue cannot grow the whole page.
        GeometryReader { _ in NativePlaybackQueueView(store: store.queue) }
      }
      else { NativeLyricsView(store: lyrics, track: track) }
    }
    .frame(minHeight: 240, maxHeight: .infinity, alignment: .top)
  }

  private var metadata: some View {
    VStack(alignment: .leading, spacing: 10) {
      NativePlayerSourceLabel()
      Text(track.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
      if let artist = track.artist { Text(artist).font(.title3).foregroundStyle(.secondary) }
      if let album = track.album { Text(album).font(.callout).foregroundStyle(.secondary) }
      NativePlaybackControls(store: store, playing: track.playing, queuePresented: $queuePresented).padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var artwork: some View {
    Group {
      if let data = track.artwork, let image = NSImage(data: data) {
        Image(nsImage: image).resizable().scaledToFill()
      } else {
        Rectangle().fill(.quaternary)
          .overlay { Image(systemName: "music.note").font(.system(size: 44)).foregroundStyle(.secondary) }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(.rect(cornerRadius: 16))
    .accessibilityLabel("专辑封面")
  }

}
