import Foundation

actor OnlineLyricsService: LyricsProviding {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)
  private let cache: LyricsDiskCache
  private let resolver: NeteaseSongIDResolver
  private let transport: Transport

  init(cache: LyricsDiskCache = .init(), resolver: NeteaseSongIDResolver = .init(), transport: Transport? = nil) {
    self.cache = cache
    self.resolver = resolver
    if let transport { self.transport = transport } else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.httpCookieStorage = nil
      configuration.httpShouldSetCookies = false
      configuration.urlCredentialStorage = nil
      configuration.urlCache = nil
      configuration.timeoutIntervalForRequest = 10
      configuration.timeoutIntervalForResource = 15
      let session = URLSession(configuration: configuration)
      self.transport = { request in
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw LyricsError.unavailable }
        return (data, response.statusCode)
      }
    }
  }

  func lyrics(for track: LyricsTrackIdentity) async throws -> LyricsLookupResult? {
    try Task.checkCancellation()
    if let document = cache.load(track) { return .init(document: document, cached: true) }
    guard let artist = track.artist, !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    var failed = false
    if let id = resolver.songID(for: track) {
      do {
        if let document = try await netease(id: id) { return try finish(document, for: track) }
      } catch {
        try Task.checkCancellation()
        failed = true
      }
    }
    do {
      if let document = try await lrclib(track) { return try finish(document, for: track) }
    } catch {
      try Task.checkCancellation()
      failed = true
    }
    if failed { throw LyricsError.unavailable }
    return nil
  }

  private func finish(_ document: LyricsDocument, for track: LyricsTrackIdentity) throws -> LyricsLookupResult {
    try Task.checkCancellation()
    cache.save(document, for: track)
    return .init(document: document, cached: false)
  }

  private func netease(id: String) async throws -> LyricsDocument? {
    let (data, status) = try await request(host: "music.163.com", path: "/api/song/lyric", query: [
      .init(name: "id", value: id), .init(name: "lv", value: "-1"),
      .init(name: "kv", value: "-1"), .init(name: "tv", value: "-1"),
    ])
    if status == 404 { return nil }
    guard status == 200 else { throw LyricsError.unavailable }
    let payload = try JSONDecoder().decode(NeteaseResponse.self, from: data)
    guard payload.code == 200 else { throw LyricsError.unavailable }
    let document = LyricsDocument(source: .netease, sourceID: id, original: payload.lrc?.lyric,
      translation: payload.tlyric?.lyric, instrumental: payload.nolyric == true)
    return document.isUsable ? document : nil
  }

  private func lrclib(_ track: LyricsTrackIdentity) async throws -> LyricsDocument? {
    var query = [URLQueryItem(name: "track_name", value: track.title), .init(name: "artist_name", value: track.artist)]
    if let album = track.album, !album.isEmpty { query.append(.init(name: "album_name", value: album)) }
    if let duration = track.duration, (1...3600).contains(duration) { query.append(.init(name: "duration", value: String(duration))) }
    let (data, status) = try await request(host: "lrclib.net", path: "/api/get", query: query)
    if status == 404 { return nil }
    guard status == 200 else { throw LyricsError.unavailable }
    let payload = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
    guard LyricsTrackIdentity.normalize(payload.trackName) == LyricsTrackIdentity.normalize(track.title),
          LyricsTrackIdentity.normalize(payload.artistName) == LyricsTrackIdentity.normalize(track.artist ?? "") else { return nil }
    if let album = track.album, !album.isEmpty,
       LyricsTrackIdentity.normalize(payload.albumName ?? "") != LyricsTrackIdentity.normalize(album) { return nil }
    if let duration = track.duration {
      guard let received = payload.duration, received.isFinite, abs(received - Double(duration)) <= 2 else { return nil }
    }
    let document = LyricsDocument(source: .lrclib, sourceID: payload.id.map(String.init), original: payload.syncedLyrics,
      plainText: payload.plainLyrics, instrumental: payload.instrumental == true)
    return document.isUsable ? document : nil
  }

  private func request(host: String, path: String, query: [URLQueryItem]) async throws -> (Data, Int) {
    try Task.checkCancellation()
    var url = URLComponents()
    url.scheme = "https"; url.host = host; url.path = path; url.queryItems = query
    guard let url = url.url else { throw LyricsError.unavailable }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
    request.httpShouldHandleCookies = false
    request.setValue("Augma/0.2.2 (https://github.com/YunYouJun/augma)", forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if host == "music.163.com" { request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer") }
    let result = try await transport(request)
    try Task.checkCancellation()
    guard result.0.count <= 2_097_152 else { throw LyricsError.unavailable }
    return result
  }

  private struct NeteaseResponse: Decodable {
    let code: Int
    let nolyric: Bool?
    let lrc: Lyric?
    let tlyric: Lyric?
    struct Lyric: Decodable { let lyric: String? }
  }
  private struct LRCLIBResponse: Decodable {
    let id: Int?
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let syncedLyrics: String?
    let plainLyrics: String?
  }
}
