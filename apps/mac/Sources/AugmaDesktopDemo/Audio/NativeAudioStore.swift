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
      if case .track(let track) = status { lyrics.update(track) } else { lyrics.clear() }
    }
  }
  let lyrics: NativeLyricsStore
  private let client: any NativeNowPlayingReading
  private let isRunning: () -> Bool
  private let now: () -> Date
  private var lifecycle: [AnyCancellable] = []
  private var observing = false
  private var sleeping = false
  private var terminated = false
  private var watchdog: Task<Void, Never>?
  private var receivedAt: Date?

  init(client: (any NativeNowPlayingReading)? = nil, lyrics: NativeLyricsStore? = nil,
       isRunning: @escaping () -> Bool = {
         !NSRunningApplication.runningApplications(withBundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier).isEmpty
       }, now: @escaping () -> Date = Date.init, observeLifecycle: Bool = true) {
    self.client = client ?? NativeNowPlayingClient()
    self.lyrics = lyrics ?? NativeLyricsStore()
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
    guard isRunning() else { status = .notRunning; return }
    switch result {
    case .success(let payload):
      status = NativeNowPlayingTrack(payload: payload, receivedAt: now()).map(NativeAudioStatus.track) ?? .idle
    case .failure: status = .unavailable
    }
  }

  func checkFreshness() {
    guard !terminated, !sleeping else { return }
    guard isRunning() else { client.stop(); status = .notRunning; return }
    if let receivedAt, now().timeIntervalSince(receivedAt) > 8 {
      client.stop()
      status = .unavailable
    }
  }

  func setSleeping(_ value: Bool) {
    sleeping = value
    if value {
      client.stop(); watchdog?.cancel(); status = .loading
    } else if observing { refresh() }
  }

  func shutdown() {
    terminated = true
    client.stop(); watchdog?.cancel(); lifecycle.removeAll()
    status = .idle
  }

  deinit { watchdog?.cancel() }
}
