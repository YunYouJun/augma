import SwiftUI

/// Keeps incoming playback samples from moving the thumb while the user scrubs.
struct NativePlaybackScrubState {
  private(set) var position: TimeInterval?
  private(set) var trackIdentifier: String?

  mutating func update(_ value: TimeInterval, track: NativeNowPlayingTrack) {
    guard value.isFinite, track.canSeek, let duration = track.duration,
          let identifier = track.trackIdentifier else { return }
    if let trackIdentifier, trackIdentifier != identifier { self = Self(); return }
    trackIdentifier = identifier
    position = min(duration, max(0, value))
  }

  mutating func takeRequest(currentIdentifier: String?) -> NativePlaybackCommand? {
    defer { self = Self() }
    guard let position, let trackIdentifier, trackIdentifier == currentIdentifier else { return nil }
    return .seek(position: position, trackIdentifier: trackIdentifier)
  }
}

struct NativePlaybackPositionView: View {
  let track: NativeNowPlayingTrack
  @ObservedObject var store: NativeAudioStore
  @State private var scrub = NativePlaybackScrubState()
  @State private var isEditing = false
  @State private var keyboardCommit: Task<Void, Never>?

  var body: some View {
    if let duration = track.duration, track.elapsed != nil {
      TimelineView(.animation(minimumInterval: 1, paused: !track.playing || isEditing)) { context in
        let elapsed = scrub.position ?? store.requestedSeekPosition ?? track.elapsed(at: context.date) ?? 0
        VStack(spacing: 4) {
          if track.canSeek {
            Slider(value: Binding(get: { elapsed }, set: { update($0) }), in: 0...duration,
                   onEditingChanged: editingChanged) { Text("播放进度") }
              .controlSize(.small)
              .labelsHidden()
              .disabled(!store.canSeek)
              .accessibilityIdentifier("native-playback-position")
              .accessibilityValue(Text("已播放 \(Self.time(elapsed))，总时长 \(Self.time(duration))"))
              .help("拖动以调整播放位置，松开后跳转")
          } else {
            ProgressView(value: elapsed, total: duration).accessibilityLabel("播放进度")
          }
          HStack { Text(Self.time(elapsed)); Spacer(); Text(Self.time(duration)) }
            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
      .onChange(of: track.trackIdentifier) { reset() }
      .onChange(of: track.canSeek) { if !track.canSeek { reset() } }
      .onDisappear { reset() }
    }
  }

  private func update(_ value: TimeInterval) {
    scrub.update(value, track: track)
    keyboardCommit?.cancel()
    // Keyboard and accessibility adjustments don't always open a mouse editing session.
    if !isEditing {
      keyboardCommit = Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
        commit()
      }
    }
  }

  private func editingChanged(_ editing: Bool) {
    keyboardCommit?.cancel(); keyboardCommit = nil
    isEditing = editing
    if !editing { commit() }
  }

  private func commit() {
    if case .seek(let position, let identifier) = scrub.takeRequest(currentIdentifier: track.trackIdentifier) {
      store.seek(to: position, trackIdentifier: identifier)
    }
  }

  private func reset() {
    keyboardCommit?.cancel(); keyboardCommit = nil
    isEditing = false
    scrub = NativePlaybackScrubState()
  }

  static func time(_ value: TimeInterval) -> String {
    let seconds = Int(min(604_800, max(0, value.isFinite ? value : 0)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
