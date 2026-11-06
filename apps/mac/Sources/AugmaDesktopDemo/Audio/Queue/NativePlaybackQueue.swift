import Foundation

struct NativePlaybackQueueItem: Identifiable, Equatable, Sendable {
  let id: Int
  let track: NeteaseSongIDResolver.Track
}

struct NativePlaybackQueue: Equatable, Sendable {
  let items: [NativePlaybackQueueItem]

  init(data: Data) throws {
    let file = try JSONDecoder().decode(QueueFile.self, from: data)
    let entries = file.list.enumerated().compactMap { index, entry -> (NativePlaybackQueueItem, Int)? in
      guard let value = entry.value, let track = value.track,
            !track.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      return (.init(id: index, track: track), entry.displayOrder.flatMap { $0 >= 0 ? $0 : nil } ?? index)
    }
    items = entries.sorted { left, right in
      left.1 == right.1 ? left.0.id < right.0.id : left.1 < right.1
    }.map(\.0)
  }

  func currentItemID(for track: NativeNowPlayingTrack) -> Int? {
    let identity = LyricsTrackIdentity(track)
    let matches = items.filter { NeteaseSongIDResolver.matches(identity, track: $0.track) }
    // Two occurrences of the same recording are ambiguous without a player queue index.
    return matches.count == 1 ? matches[0].id : nil
  }

  private struct QueueFile: Decodable { let list: [QueueEntry] }
  private struct QueueEntry: Decodable {
    let value: NeteaseSongIDResolver.Entry?
    let displayOrder: Int?
    private enum CodingKeys: String, CodingKey { case displayOrder }
    init(from decoder: any Decoder) throws {
      value = try? NeteaseSongIDResolver.Entry(from: decoder)
      if let container = try? decoder.container(keyedBy: CodingKeys.self) {
        displayOrder = try? container.decode(Int.self, forKey: .displayOrder)
      } else { displayOrder = nil }
    }
  }
}

protocol NativePlaybackQueueReading: Sendable {
  func read() async throws -> NativePlaybackQueue
}

struct NeteasePlaybackQueueClient: NativePlaybackQueueReading {
  let url: URL
  init(url: URL = NeteaseSongIDResolver().queueURL) { self.url = url }

  func read() async throws -> NativePlaybackQueue {
    try await Task.detached(priority: .utility) { [url] in
      let maximumSize = 16_777_216
      guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maximumSize else {
        throw NativeNowPlayingError.unavailable
      }
      let data = try Data(contentsOf: url)
      guard data.count <= maximumSize else { throw NativeNowPlayingError.unavailable }
      return try NativePlaybackQueue(data: data)
    }.value
  }
}
