import Combine
import Foundation

enum NativePlaybackQueueState: Equatable {
  case idle, loading, unavailable
  case available(NativePlaybackQueue)
}

/// Reads only while a queue view is visible, shared by all audio surfaces.
@MainActor
final class NativePlaybackQueueStore: ObservableObject {
  @Published private(set) var state: NativePlaybackQueueState = .idle
  @Published private(set) var currentItemID: Int?
  @Published private(set) var playing = false
  private let client: any NativePlaybackQueueReading
  private var currentTrack: NativeNowPlayingTrack?
  private var viewers = 0
  private var terminated = false
  private var generation = UUID()
  private var polling: Task<Void, Never>?
  private var request: Task<Void, Never>?

  init(client: any NativePlaybackQueueReading = NeteasePlaybackQueueClient()) { self.client = client }

  func update(_ track: NativeNowPlayingTrack?) {
    guard !terminated else { return }
    currentTrack = track
    if playing != (track?.playing == true) { playing = track?.playing == true }
    guard track != nil else { clear(); return }
    updateHighlight()
    if viewers > 0 { startPolling() }
  }

  func startObserving() {
    guard !terminated else { return }
    viewers += 1
    if currentTrack != nil { startPolling() }
  }

  func stopObserving() {
    viewers = max(0, viewers - 1)
    if viewers == 0 { clear() }
  }

  private func startPolling() {
    guard polling == nil else { return }
    refresh()
    polling = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(3)) } catch { return }
        self?.refresh()
      }
    }
  }

  func refresh() {
    guard !terminated, viewers > 0, currentTrack != nil, request == nil else { return }
    if state == .idle { state = .loading }
    let token = generation
    request = Task { [weak self, client] in
      do {
        try Task.checkCancellation()
        let queue = try await client.read()
        guard let self, !Task.isCancelled, self.generation == token else { return }
        if self.state != .available(queue) { self.state = .available(queue) }
        self.updateHighlight()
        self.request = nil
      } catch {
        guard let self, !Task.isCancelled, self.generation == token else { return }
        self.state = .unavailable
        self.currentItemID = nil
        self.request = nil
      }
    }
  }

  private func updateHighlight() {
    let id: Int?
    if case .available(let queue) = state, let currentTrack {
      id = queue.currentItemID(for: currentTrack)
    } else { id = nil }
    if currentItemID != id { currentItemID = id }
  }

  private func clear() {
    generation = UUID()
    polling?.cancel(); polling = nil
    request?.cancel(); request = nil
    state = .idle
    currentItemID = nil
  }

  func shutdown() { terminated = true; currentTrack = nil; playing = false; clear() }
  deinit { polling?.cancel(); request?.cancel() }
}
