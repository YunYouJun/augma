import Foundation

/// A sample from the local media session, never a persisted listening history.
struct NativeNowPlayingPayload: Decodable, Sendable {
  var bundleIdentifier: String?
  var title: String?
  var artist: String?
  var album: String?
  var playing: Bool?
  var duration: Double?
  var elapsed: Double?
  var rate: Double?
  var timestamp: Double?
  var artwork: Data?
  var lyrics: String?
  var error: String?
  var trackIdentifier: String?
  var canSeek: Bool?
}

struct NativeNowPlayingTrack: Equatable, Sendable {
  static let neteaseBundleIdentifier = "com.netease.163music"
  let title: String
  let artist: String?
  let album: String?
  let playing: Bool
  let duration: TimeInterval?
  let elapsed: TimeInterval?
  let rate: Double
  let sampledAt: Date
  let artwork: Data?
  let lyrics: String?
  let trackIdentifier: String?
  let canSeek: Bool

  init?(payload: NativeNowPlayingPayload, receivedAt: Date) {
    guard payload.bundleIdentifier == Self.neteaseBundleIdentifier,
          let title = Self.nonempty(payload.title) else { return nil }
    self.title = title
    artist = Self.nonempty(payload.artist)
    album = Self.nonempty(payload.album)
    playing = payload.playing == true
    duration = payload.duration.flatMap { $0.isFinite && $0 > 0 && $0 <= 604_800 ? $0 : nil }
    let speed = payload.rate ?? 1
    rate = speed.isFinite && speed >= 0 && speed <= 16 ? speed : 1
    sampledAt = receivedAt
    if let value = payload.elapsed, value.isFinite, value >= 0 {
      let delta = payload.timestamp.flatMap { $0.isFinite ? max(0, receivedAt.timeIntervalSince1970 - $0) : nil } ?? 0
      let current = value + (playing ? delta * rate : 0)
      elapsed = min(duration ?? 604_800, max(0, current))
    } else { elapsed = nil }
    artwork = payload.artwork.flatMap { $0.count <= 4_194_304 ? $0 : nil }
    lyrics = Self.nonempty(payload.lyrics)
    trackIdentifier = Self.nonempty(payload.trackIdentifier).flatMap { $0.utf8.count <= 4096 ? $0 : nil }
    canSeek = payload.canSeek == true && trackIdentifier != nil && duration != nil && elapsed != nil
  }

  func elapsed(at date: Date) -> TimeInterval? {
    guard let elapsed else { return nil }
    let current = elapsed + (playing ? max(0, date.timeIntervalSince(sampledAt)) * rate : 0)
    return min(duration ?? 604_800, current)
  }

  private static func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }
}
