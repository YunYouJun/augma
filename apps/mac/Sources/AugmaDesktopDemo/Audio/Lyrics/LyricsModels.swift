import Foundation

struct LyricsTrackIdentity: Codable, Hashable, Sendable {
  let title: String
  let artist: String?
  let album: String?
  let duration: Int?

  init(title: String, artist: String?, album: String?, duration: TimeInterval?) {
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration.flatMap { $0.isFinite && $0 > 0 && $0 < 604_800 ? Int($0.rounded()) : nil }
  }

  init(_ track: NativeNowPlayingTrack) {
    self.init(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
  }

  var signature: String {
    [Self.normalize(title), Self.normalize(artist ?? ""), Self.normalize(album ?? ""), duration.map(String.init) ?? ""].joined(separator: "\u{1f}")
  }

  static func normalize(_ value: String) -> String {
    value.precomposedStringWithCompatibilityMapping
      .replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
      .replacingOccurrences(of: "’", with: "'")
      .lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }
}

enum LyricsSource: String, Codable, Sendable {
  case netease, lrclib, metadata
  var title: String {
    switch self {
    case .netease: String(appLocalized: "网易云音乐")
    case .lrclib: "LRCLIB"
    case .metadata: String(appLocalized: "播放元数据")
    }
  }
}

struct LyricsLine: Codable, Equatable, Identifiable, Sendable {
  let time: TimeInterval
  let text: String
  var translation: String?
  var id: TimeInterval { time }
}

struct LyricsDocument: Codable, Equatable, Sendable {
  let source: LyricsSource
  let sourceID: String?
  let lines: [LyricsLine]
  let plainText: String?
  let instrumental: Bool

  init(source: LyricsSource, sourceID: String? = nil, original: String? = nil,
       translation: String? = nil, plainText: String? = nil, instrumental: Bool = false) {
    self.source = source
    self.sourceID = sourceID
    self.instrumental = instrumental
    lines = instrumental ? [] : LRCParser.parse(original ?? "", translation: translation)
    let plain = plainText ?? (lines.isEmpty ? original : nil)
    self.plainText = instrumental ? nil : plain.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
  }

  var isUsable: Bool { instrumental || !lines.isEmpty || plainText != nil }

  func activeLine(at elapsed: TimeInterval) -> Int? {
    guard elapsed.isFinite, !lines.isEmpty, elapsed >= lines[0].time else { return nil }
    var low = 0, high = lines.count
    while low < high {
      let middle = (low + high) / 2
      if lines[middle].time <= elapsed { low = middle + 1 } else { high = middle }
    }
    return low - 1
  }
}

struct LyricsLookupResult: Sendable {
  let document: LyricsDocument
  let cached: Bool
}

enum LyricsError: Error { case unavailable }

protocol LyricsProviding: Sendable {
  func lyrics(for track: LyricsTrackIdentity) async throws -> LyricsLookupResult?
}
