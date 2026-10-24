import SwiftUI

struct NativeAudioView: View {
  @ObservedObject var store: NativeAudioStore

  var body: some View {
    Form {
      Section {
        Picker("声音库", selection: Binding(get: { store.trackIndex }, set: store.selectTrack)) {
          ForEach(Array(NativeAudioStore.tracks.enumerated()), id: \.element.id) { index, track in
            Text(track.name).tag(index)
          }
        }
        Text(NativeAudioStore.tracks[store.trackIndex].subtitle)
          .foregroundStyle(.secondary)
        NativeAudioProgressView(store: store)
        HStack {
          Button("上一首", systemImage: "backward.end.fill", action: store.previous)
            .labelStyle(.iconOnly)
          Spacer()
          Button(store.playing ? String(localized: "暂停") : String(localized: "播放"), systemImage: store.playing ? "pause.fill" : "play.fill") {
            if store.playing { store.pause() } else { store.play() }
          }
          .buttonStyle(.borderedProminent)
          .disabled(store.busy)
          Spacer()
          Button("下一首", systemImage: "forward.end.fill", action: store.next)
            .labelStyle(.iconOnly)
        }
        Slider(value: Binding(get: { store.volume }, set: {
          if store.volume != $0 { store.volume = $0 }
        }), in: 0...100, step: 1) { Text("音量") }
        if let error = store.error {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
      Section {
        Text("声音在本机合成，播放不需要网络。关闭窗口后继续播放，暂停或退出 App 时停止。")
          .font(.callout).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

private struct NativeAudioProgressView: View {
  @ObservedObject var store: NativeAudioStore
  @State private var draft: Double?
  @State private var editing = false

  var body: some View {
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
    HStack {
      Text(time(draft ?? store.elapsed))
      Spacer()
      Text(time(store.duration))
    }
    .monospacedDigit().foregroundStyle(.secondary)
  }

  private func time(_ value: Double) -> String {
    let seconds = max(0, Int(value))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
