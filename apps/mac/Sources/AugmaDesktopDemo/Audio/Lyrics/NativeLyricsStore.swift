import Combine
import Foundation

enum NativeLyricsState {
  case idle, loading, notFound, failed
  case available(LyricsLookupResult)
}

@MainActor
final class NativeLyricsStore: ObservableObject {
  @Published private(set) var state: NativeLyricsState = .idle
  private let service: any LyricsProviding
  private var identity: LyricsTrackIdentity?
  private var request: Task<Void, Never>?
  private var generation = UUID()

  init(service: any LyricsProviding = OnlineLyricsService()) { self.service = service }

  func update(_ track: NativeNowPlayingTrack?) {
    guard let track else { clear(); return }
    let identity = LyricsTrackIdentity(track)
    // Playback samples arrive every two seconds. Only a new song starts a lookup.
    guard self.identity != identity else { return }
    clear()
    self.identity = identity
    if let local = track.lyrics {
      state = .available(.init(document: .init(source: .metadata, original: local), cached: false))
      return
    }
    state = .loading
    let token = generation
    request = Task { [weak self, service] in
      do {
        let result = try await service.lyrics(for: identity)
        guard let self, !Task.isCancelled, self.generation == token else { return }
        self.state = result.map(NativeLyricsState.available) ?? .notFound
      } catch {
        guard let self, !Task.isCancelled, self.generation == token else { return }
        self.state = .failed
      }
    }
  }

  func retry(_ track: NativeNowPlayingTrack) { clear(); update(track) }

  func clear() {
    generation = UUID()
    request?.cancel(); request = nil
    identity = nil
    state = .idle
  }

  deinit { request?.cancel() }
}
