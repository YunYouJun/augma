import AppKit
import Combine

enum NativeAudioStatus: Equatable {
  case loading, notRunning, idle, unavailable
  case track(NativeNowPlayingTrack)
}

/// Shared across windows. Observing never starts, stops or changes audio.
@MainActor
final class NativeAudioStore: ObservableObject {
  @Published private(set) var status: NativeAudioStatus = .loading {
    didSet {
      if case .track(let track) = status {
        lyrics.update(track); queue.update(track)
      } else { lyrics.clear(); queue.update(nil) }
    }
  }
  @Published private(set) var isChangingPlayback = false
  @Published private(set) var playbackError: String?
  @Published private(set) var requestedSeekPosition: TimeInterval?
  let lyrics: NativeLyricsStore
  let queue: NativePlaybackQueueStore
  private let client: any NativeNowPlayingReading
  private let playback: any NativePlaybackControlling
  private let isRunning: () -> Bool
  private let now: () -> Date
  private var lifecycle: [AnyCancellable] = []
  private var observing = false
  private var sleeping = false
  private var terminated = false
  private var watchdog: Task<Void, Never>?
  private var receivedAt: Date?
  private var playbackTask: Task<Void, Never>?
  private var playbackGeneration = UUID()
  private var requestedCommand: NativePlaybackCommand?
  private var commandAcknowledged = false
  private var requestedAt: Date?
  private let playbackConfirmationTimeout: Duration

  init(client: (any NativeNowPlayingReading)? = nil, lyrics: NativeLyricsStore? = nil,
       queue: NativePlaybackQueueStore? = nil,
       playback: (any NativePlaybackControlling)? = nil, playbackConfirmationTimeout: Duration = .seconds(5),
       isRunning: @escaping () -> Bool = {
         !NSRunningApplication.runningApplications(withBundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier).isEmpty
       }, now: @escaping () -> Date = Date.init, observeLifecycle: Bool = true) {
    self.client = client ?? NativeNowPlayingClient()
    self.playback = playback ?? NativePlaybackClient()
    self.playbackConfirmationTimeout = playbackConfirmationTimeout
    self.lyrics = lyrics ?? NativeLyricsStore()
    self.queue = queue ?? NativePlaybackQueueStore()
    self.isRunning = isRunning
    self.now = now
    if observeLifecycle {
      let center = NSWorkspace.shared.notificationCenter
      center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
        .merge(with: center.publisher(for: NSWorkspace.didLaunchApplicationNotification))
        .receive(on: RunLoop.main)
        .sink { [weak self] notification in
          guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier == NativeNowPlayingTrack.neteaseBundleIdentifier else { return }
          if self?.observing == true { self?.refresh() }
        }.store(in: &lifecycle)
      center.publisher(for: NSWorkspace.willSleepNotification).receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(true) }.store(in: &lifecycle)
      center.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(false) }.store(in: &lifecycle)
    }
  }

  func startObserving() {
    guard !observing, !terminated else { return }
    observing = true
    refresh()
  }

  func refresh() {
    guard !terminated, !sleeping else { return }
    cancelPlayback()
    watchdog?.cancel()
    client.stop()
    receivedAt = nil
    guard isRunning() else { status = .notRunning; return }
    status = .loading
    receivedAt = now()
    client.start { [weak self] result in self?.receive(result) }
    watchdog = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
        self?.checkFreshness()
      }
    }
  }

  private func receive(_ result: Result<NativeNowPlayingPayload, NativeNowPlayingError>) {
    guard !terminated, !sleeping else { return }
    receivedAt = now()
    guard isRunning() else { cancelPlayback(); status = .notRunning; return }
    switch result {
    case .success(let payload):
      status = NativeNowPlayingTrack(payload: payload, receivedAt: now()).map(NativeAudioStatus.track) ?? .idle
    case .failure: status = .unavailable
    }
    if case .track(let track) = status {
      if let requestedPlaying = requestedCommand?.targetPlaying, requestedPlaying == track.playing { cancelPlayback() }
      else if case .seek(_, let identifier) = requestedCommand {
        if track.trackIdentifier != identifier { cancelPlayback() }
        else { confirmSeekIfObserved(track) }
      }
    } else { cancelPlayback() }
  }

  var canControlPlayback: Bool {
    guard !terminated, !sleeping, !isChangingPlayback, isRunning(),
          case .track = status, let receivedAt else { return false }
    return now().timeIntervalSince(receivedAt) <= 8
  }

  func togglePlayback() {
    guard canControlPlayback, case .track(let track) = status else { return }
    performPlayback(track.playing ? .pause : .play)
  }

  func previousTrack() { performPlayback(.previousTrack) }
  func nextTrack() { performPlayback(.nextTrack) }

  var canSeek: Bool {
    guard canControlPlayback, case .track(let track) = status else { return false }
    return track.canSeek
  }

  func seek(to position: TimeInterval, trackIdentifier: String) {
    guard canSeek, position.isFinite, case .track(let track) = status,
          track.trackIdentifier == trackIdentifier, let duration = track.duration else { return }
    performPlayback(.seek(position: min(duration, max(0, position)), trackIdentifier: trackIdentifier))
  }

  private func performPlayback(_ command: NativePlaybackCommand) {
    guard canControlPlayback else { return }
    playbackError = nil
    requestedCommand = command
    requestedAt = now()
    commandAcknowledged = false
    if case .seek(let position, _) = command { requestedSeekPosition = position }
    isChangingPlayback = true
    let token = UUID()
    playbackGeneration = token
    playbackTask = Task { [weak self, playback, playbackConfirmationTimeout] in
      do {
        try Task.checkCancellation()
        try await playback.send(command)
        guard let self, self.playbackGeneration == token else { return }
        self.commandAcknowledged = true
        if case .seek = command {
          if case .track(let track) = self.status { self.confirmSeekIfObserved(track) }
          guard self.playbackGeneration == token else { return }
        }
        // A previous-track request may restart the same song. Use the player's
        // command acknowledgement for skips; metadata continues to come from the reader.
        else if command.targetPlaying == nil { self.cancelPlayback(); return }
        try await Task.sleep(for: playbackConfirmationTimeout)
        guard self.playbackGeneration == token else { return }
        self.failPlayback()
      } catch {
        guard let self, self.playbackGeneration == token else { return }
        self.failPlayback()
      }
    }
  }

  private func failPlayback() {
    let seeking = requestedSeekPosition != nil
    cancelPlayback()
    playbackError = seeking
      ? String(appLocalized: "未能确认播放位置，请重试或在网易云音乐中拖动进度条。")
      : String(appLocalized: "播放操作未完成，请重试或在网易云音乐中操作。")
  }

  private func confirmSeekIfObserved(_ track: NativeNowPlayingTrack) {
    guard commandAcknowledged, case .seek(let position, let identifier) = requestedCommand,
          track.trackIdentifier == identifier, let actual = track.elapsed(at: now()), let requestedAt else { return }
    let advance = track.playing ? max(0, now().timeIntervalSince(requestedAt)) * track.rate : 0
    if actual >= max(0, position - 2), actual <= min(track.duration ?? 604_800, position + advance + 2) {
      cancelPlayback()
    }
  }

  private func cancelPlayback() {
    playbackGeneration = UUID()
    playbackTask?.cancel(); playbackTask = nil
    requestedCommand = nil
    requestedAt = nil
    commandAcknowledged = false
    requestedSeekPosition = nil
    isChangingPlayback = false
    playbackError = nil
  }

  func checkFreshness() {
    guard !terminated, !sleeping else { return }
    guard isRunning() else { client.stop(); cancelPlayback(); status = .notRunning; return }
    if let receivedAt, now().timeIntervalSince(receivedAt) > 8 {
      client.stop()
      cancelPlayback()
      status = .unavailable
    }
  }

  func setSleeping(_ value: Bool) {
    sleeping = value
    if value {
      cancelPlayback()
      client.stop(); watchdog?.cancel(); status = .loading
    } else if observing { refresh() }
  }

  func shutdown() {
    terminated = true
    cancelPlayback()
    client.stop(); watchdog?.cancel(); lifecycle.removeAll()
    status = .idle
    queue.shutdown()
  }

  deinit { watchdog?.cancel(); playbackTask?.cancel() }
}
