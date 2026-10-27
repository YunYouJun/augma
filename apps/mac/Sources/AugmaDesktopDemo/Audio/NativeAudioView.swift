import SwiftUI

struct NativeAudioView: View {
  @ObservedObject var store: NativeAudioStore

  var body: some View {
    NativePage {
      NativePageSection("声音") {
        VStack(alignment: .leading, spacing: 8) {
          Text("声音库").font(.callout.weight(.medium))
          Picker("声音库", selection: Binding(get: { store.trackIndex }, set: store.selectTrack)) {
            ForEach(Array(NativeAudioStore.tracks.enumerated()), id: \.element.id) { index, track in
              Text(track.name).tag(index)
            }
          }
          .labelsHidden()
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        Text(NativeAudioStore.tracks[store.trackIndex].subtitle)
          .font(.callout).foregroundStyle(.secondary)
        NativeAudioProgressView(store: store)
        HStack(spacing: 20) {
          Button(action: store.previous) {
            Label("上一首", systemImage: "backward.end.fill")
              .labelStyle(.iconOnly)
              .frame(width: 16, height: 16)
          }
          .frame(width: 36, height: 36)
          Button(store.playing ? String(localized: "暂停") : String(localized: "播放"), systemImage: store.playing ? "pause.fill" : "play.fill") {
            if store.playing { store.pause() } else { store.play() }
          }
          .buttonStyle(.borderedProminent)
          .disabled(store.busy)
          Button(action: store.next) {
            Label("下一首", systemImage: "forward.end.fill")
              .labelStyle(.iconOnly)
              .frame(width: 16, height: 16)
          }
          .frame(width: 36, height: 36)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("音量").font(.callout.weight(.medium))
            Spacer()
            Text("\(Int(store.volume))%")
              .monospacedDigit().foregroundStyle(.secondary)
          }
          Slider(value: Binding(get: { store.volume }, set: {
            if store.volume != $0 { store.volume = $0 }
          }), in: 0...100, step: 1) { Text("音量") }
            .labelsHidden()
        }
        if let error = store.error {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
      Text("声音在本机合成，播放不需要网络。关闭窗口后继续播放，暂停或退出 App 时停止。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}

private struct NativeAudioProgressView: View {
  @ObservedObject var store: NativeAudioStore
  @State private var draft: Double?
  @State private var editing = false

  var body: some View {
    VStack(spacing: 8) {
      Slider(value: Binding(get: { draft ?? store.elapsed }, set: {
        guard $0 != (draft ?? store.elapsed) else { return }
        if editing { draft = $0 }
        else { store.seek($0) }
      }), in: 0...store.duration) {
        Text("播放进度")
      } onEditingChanged: { isEditing in
        editing = isEditing
        if !isEditing, let draft {
          store.seek(draft)
          self.draft = nil
        }
      }
      .labelsHidden()
      HStack {
        Text(time(draft ?? store.elapsed))
        Spacer()
        Text(time(store.duration))
      }
      .font(.caption).monospacedDigit().foregroundStyle(.secondary)
    }
  }

  private func time(_ value: Double) -> String {
    let seconds = max(0, Int(value))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
