import Foundation

enum NativeBrowserAddressError: Error, Equatable {
  case empty, invalid, unsupportedScheme, tooLong

  var message: String {
    switch self {
    case .empty: String(localized: "请输入网址或搜索内容。")
    case .invalid: String(localized: "网址无效，请检查后重试。")
    case .unsupportedScheme: String(localized: "仅支持 HTTP 和 HTTPS 网页。")
    case .tooLong: String(localized: "网址或搜索内容过长。")
    }
  }
}

/// Address entry is resolved before WebKit exists; text never becomes executable JavaScript.
enum NativeBrowserAddress {
  static func resolve(_ input: String) throws -> URL {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw NativeBrowserAddressError.empty }
    guard text.utf8.count <= 8_192 else { throw NativeBrowserAddressError.tooLong }
    guard text.rangeOfCharacter(from: .controlCharacters) == nil else { throw NativeBrowserAddressError.invalid }

    if text.hasPrefix("//") { return try validatedURL("https:" + text) }

    // A host followed by a numeric port is an address, not a custom URL scheme.
    let authority = String(text.split(maxSplits: 1, whereSeparator: { "/?#".contains($0) }).first ?? "")
    let hostAndPort = authority.split(separator: ":", maxSplits: 1)
    let hasHostPort = hostAndPort.count == 2
      && (hostAndPort[0].contains(".") || hostAndPort[0] == "localhost")
      && !hostAndPort[1].isEmpty && hostAndPort[1].allSatisfy(\.isNumber)
    let hasScheme = text.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil
    if hasScheme && !hasHostPort {
      guard text.lowercased().hasPrefix("https://") || text.lowercased().hasPrefix("http://") else {
        throw NativeBrowserAddressError.unsupportedScheme
      }
      return try validatedURL(text)
    }

    let hasWhitespace = text.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    let host = authority.split(separator: "?", maxSplits: 1).first.map(String.init) ?? authority
    if !hasWhitespace && (host.contains(".") || host == "localhost" || hasHostPort || host.hasPrefix("[")) {
      return try validatedURL("https://" + text)
    }

    var search = URLComponents(string: "https://www.bing.com/search")!
    search.queryItems = [URLQueryItem(name: "q", value: text)]
    guard let url = search.url else { throw NativeBrowserAddressError.invalid }
    return url
  }

  static func permits(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
          let host = url.host, !host.isEmpty,
          host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          url.user == nil, url.password == nil else { return false }
    if let port = url.port, !(1...65_535).contains(port) { return false }
    return true
  }

  private static func validatedURL(_ text: String) throws -> URL {
    guard let url = URL(string: text), permits(url) else { throw NativeBrowserAddressError.invalid }
    return url
  }
}
