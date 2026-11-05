import Darwin
import Foundation

/// Reads only the play queue, never credentials, cookies or listening-history files.
struct NeteaseSongIDResolver: Sendable {
  let queueURL: URL

  init(queueURL: URL? = nil) {
    // The player belongs to the system user, even when Augma uses a separate
    // Cocoa profile for acceptance. CFFIXED_USER_HOME must not redirect it.
    let home = Self.systemUserHome ?? FileManager.default.homeDirectoryForCurrentUser
    self.queueURL = queueURL ?? home.appending(path: "Library/Application Support/com.netease.163music/Documents/storage/file_storage/webdata/file/playingList")
  }

  private static var systemUserHome: URL? {
    var entry = passwd()
    var result: UnsafeMutablePointer<passwd>?
    var buffer = [CChar](repeating: 0, count: 16_384)
    return buffer.withUnsafeMutableBufferPointer { bytes in
      guard getpwuid_r(getuid(), &entry, bytes.baseAddress, bytes.count, &result) == 0,
            let directory = result?.pointee.pw_dir else { return nil }
      return URL(filePath: String(cString: directory))
    }
  }

  func songID(for identity: LyricsTrackIdentity) -> String? {
    guard let size = try? queueURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 16_777_216,
          let data = try? Data(contentsOf: queueURL), let queue = try? JSONDecoder().decode(Queue.self, from: data) else { return nil }
    return Self.match(identity, entries: queue.list)
  }

  static func match(_ identity: LyricsTrackIdentity, entries: [Entry]) -> String? {
    guard let artist = identity.artist, !LyricsTrackIdentity.normalize(artist).isEmpty else { return nil }
    let matches = entries.compactMap { entry -> String? in
      guard let track = entry.track,
            LyricsTrackIdentity.normalize(track.name) == LyricsTrackIdentity.normalize(identity.title),
            artistsMatch(artist, track.artists.map(\.name)) else { return nil }
      if let album = identity.album, !album.isEmpty,
         LyricsTrackIdentity.normalize(track.album?.name ?? "") != LyricsTrackIdentity.normalize(album) { return nil }
      if let duration = identity.duration {
        guard let milliseconds = track.duration, milliseconds.isFinite, abs(milliseconds / 1000 - Double(duration)) <= 2 else { return nil }
      }
      return track.id?.value
    }
    let ids = Set(matches)
    return ids.count == 1 ? ids.first : nil
  }

  static func artistsMatch(_ text: String, _ names: [String]) -> Bool {
    let expected = LyricsTrackIdentity.normalize(text)
    let normalized = names.map(LyricsTrackIdentity.normalize)
    // NetEase's system media session can report only one credited artist even
    // when its own queue lists the full cast. Require an exact credited name;
    // title, album, duration and the unique matching ID are checked separately.
    if normalized.contains(expected) { return true }
    for separator in ["/", " / ", ", ", "、", " & ", "; "] where LyricsTrackIdentity.normalize(normalized.joined(separator: separator)) == expected { return true }
    return false
  }

  struct Queue: Decodable { let list: [Entry] }
  struct Entry: Decodable { let track: Track? }
  struct Track: Decodable {
    let id: SongID?
    let name: String
    let artists: [Artist]
    let album: Album?
    let duration: Double?
  }
  struct Artist: Decodable { let name: String }
  struct Album: Decodable { let name: String }
  struct SongID: Decodable {
    let value: String
    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      let text: String
      if let string = try? container.decode(String.self) { text = string } else { text = String(try container.decode(Int64.self)) }
      guard !text.isEmpty, text.count <= 20, text.allSatisfy({ $0.isASCII && $0.isNumber }) else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid song ID")
      }
      value = text
    }
  }
}
