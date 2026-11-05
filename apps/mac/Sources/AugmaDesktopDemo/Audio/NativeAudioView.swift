import SwiftUI

struct NativeAudioView: View {
  @ObservedObject var store: NativeAudioStore

  var body: some View {
    NativePage {
      NativePageSection("正在播放") {
        switch store.status {
        case .track(let track): NativeNowPlayingContent(track: track, lyrics: store.lyrics)
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
      Text("读取本机播放信息，联网获取歌词并缓存在本机。播放操作请在网易云音乐中完成。")
        .font(.caption).foregroundStyle(.secondary)
    }
    .onAppear { store.startObserving() }
  }
}

private struct NativeNowPlayingContent: View {
  let track: NativeNowPlayingTrack
  let lyrics: NativeLyricsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 24) { artwork; metadata }
        VStack(alignment: .leading, spacing: 20) { artwork; metadata }
      }
      if track.elapsed != nil, let duration = track.duration {
        TimelineView(.animation(minimumInterval: 1, paused: !track.playing)) { context in
          let elapsed = track.elapsed(at: context.date) ?? 0
          VStack(spacing: 8) {
            ProgressView(value: elapsed, total: duration).accessibilityLabel("播放进度")
            HStack { Text(time(elapsed)); Spacer(); Text(time(duration)) }
              .font(.caption).monospacedDigit().foregroundStyle(.secondary)
          }
        }
      }
      Divider()
      NativeLyricsView(store: lyrics, track: track)
    }
    .textSelection(.enabled)
  }

  private var metadata: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("网易云音乐", systemImage: "music.note").font(.caption).foregroundStyle(.secondary)
      Text(track.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
      if let artist = track.artist { Text(artist).font(.title3).foregroundStyle(.secondary) }
      if let album = track.album { Text(album).font(.callout).foregroundStyle(.secondary) }
      Label(track.playing ? String(localized: "正在播放") : String(localized: "已暂停"),
            systemImage: track.playing ? "waveform" : "pause.fill")
        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
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
    .frame(width: 128, height: 128)
    .clipShape(.rect(cornerRadius: 16))
    .accessibilityLabel("专辑封面")
  }

  private func time(_ value: TimeInterval) -> String {
    let seconds = Int(max(0, value))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
