import CryptoKit
import Foundation

/// Versioned, bounded cache. Filenames contain only hashes; no account data is stored.
struct LyricsDiskCache: Sendable {
  let directory: URL
  let maximumEntries: Int

  init(directory: URL? = nil, maximumEntries: Int = 256) {
    self.directory = directory ?? URL.cachesDirectory.appending(path: "\(Bundle.main.bundleIdentifier ?? "cn.yunyoujun.augma.desktop-demo")/Lyrics/v1")
    self.maximumEntries = max(1, maximumEntries)
  }

  func load(_ track: LyricsTrackIdentity) -> LyricsDocument? {
    let url = fileURL(track)
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2_097_152,
          let data = try? Data(contentsOf: url), let entry = try? JSONDecoder().decode(Entry.self, from: data),
          entry.version == 1, entry.signature == track.signature, entry.document.isUsable,
          entry.document.lines.allSatisfy({ $0.time.isFinite && $0.time >= 0 }),
          zip(entry.document.lines, entry.document.lines.dropFirst()).allSatisfy({ $0.time < $1.time }) else { return nil }
    try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    return entry.document
  }

  func save(_ document: LyricsDocument, for track: LyricsTrackIdentity) {
    guard document.isUsable, let data = try? JSONEncoder().encode(Entry(version: 1, signature: track.signature, document: document)), data.count <= 2_097_152 else { return }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      let url = fileURL(track)
      try data.write(to: url, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
      prune()
    } catch { /* Cache failures do not prevent showing downloaded lyrics. */ }
  }

  func fileURL(_ track: LyricsTrackIdentity) -> URL {
    let hash = SHA256.hash(data: Data(track.signature.utf8)).map { String(format: "%02x", $0) }.joined()
    return directory.appending(path: hash + ".json")
  }

  private func prune() {
    let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    let entries = files.filter { $0.pathExtension == "json" }.sorted {
      ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
    }
    for url in entries.dropFirst(maximumEntries) { try? FileManager.default.removeItem(at: url) }
  }

  private struct Entry: Codable {
    let version: Int
    let signature: String
    let document: LyricsDocument
  }
}
