import SwiftUI

struct NativePlaybackControls: View {
  @ObservedObject var store: NativeAudioStore
  let playing: Bool
  @Binding var queuePresented: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Button("上一曲", systemImage: "backward.end.fill") { store.previousTrack() }
          .buttonStyle(.borderless)
          .frame(width: 32, height: 36)
          .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
          .help("上一曲（⌥⌘←）")

        Button {
          store.togglePlayback()
        } label: {
          Label(playing ? String(appLocalized: "暂停") : String(appLocalized: "播放"),
                systemImage: playing ? "pause.fill" : "play.fill")
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .keyboardShortcut("p", modifiers: [.command, .option])
        .help("播放或暂停网易云音乐（⌥⌘P）")

        Button("下一曲", systemImage: "forward.end.fill") { store.nextTrack() }
          .buttonStyle(.borderless)
          .frame(width: 32, height: 36)
          .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
          .help("下一曲（⌥⌘→）")

        Button("当前播放队列", systemImage: "list.bullet") { queuePresented.toggle() }
          .buttonStyle(.borderless)
          .foregroundStyle(queuePresented ? Color.accentColor : Color.secondary)
          .frame(width: 32, height: 36)
          .help("显示或隐藏当前播放队列")
      }
      .labelStyle(.iconOnly)
      .font(.title3)
      .disabled(!store.canControlPlayback)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("播放控制")

      Label(playing ? String(appLocalized: "正在播放") : String(appLocalized: "已暂停"),
            systemImage: playing ? "waveform" : "pause.fill")
        .font(.caption).foregroundStyle(.secondary)
        // Keep the status row stable across playback updates and symbol changes.
        .frame(minHeight: 16, alignment: .leading)
    }
  }
}
