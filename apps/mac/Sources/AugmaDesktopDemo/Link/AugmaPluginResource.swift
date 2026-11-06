import Foundation

/// Only files in the validated package inventory can cross the WebKit resource seam.
struct AugmaPluginResource {
  static let scheme = "augma-plugin"
  static let contentPolicy = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; media-src 'self'; connect-src 'self'; frame-src 'none'; worker-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'"
  let package: AugmaPluginPackage

  var entryURL: URL { URL(string: "\(Self.scheme)://\(package.manifest.id)/\(package.manifest.entry)")! }

  func allows(_ url: URL) -> Bool { (try? relativePath(url)) != nil }

  func read(_ url: URL) throws -> (data: Data, mime: String) {
    let path = try relativePath(url)
    let file = package.root.appending(path: path)
    guard file.path == file.resolvingSymlinksInPath().path else { throw AugmaPluginError.invalidPackage }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular,
          (attributes[.referenceCount] as? NSNumber)?.intValue == 1,
          (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= AugmaPluginPackageReader.maximumFileBytes else {
      throw AugmaPluginError.invalidPackage
    }
    var data = try Data(contentsOf: file)
    let ext = file.pathExtension.lowercased()
    if ext == "html" {
      guard let html = String(data: data, encoding: .utf8) else { throw AugmaPluginError.invalidPackage }
      let policy = "<meta http-equiv=\"Content-Security-Policy\" content=\"\(Self.contentPolicy)\">"
      // Keep the doctype first for standards mode, then apply policy before any author markup or script.
      if let doctype = html.range(of: #"^\s*<!doctype\s+html[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
        data = Data((String(html[..<doctype.upperBound]) + policy + String(html[doctype.upperBound...])).utf8)
      } else { data = Data(("<!doctype html>" + policy + html).utf8) }
    }
    let types = ["html": "text/html", "css": "text/css", "js": "text/javascript", "json": "application/json",
      "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
      "webp": "image/webp", "woff": "font/woff", "woff2": "font/woff2", "txt": "text/plain"]
    return (data, types[ext] ?? "application/octet-stream")
  }

  private func relativePath(_ url: URL) throws -> String {
    guard url.scheme == Self.scheme, url.host == package.manifest.id, url.user == nil, url.password == nil,
          url.port == nil, url.query == nil,
          let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath.removingPercentEncoding,
          path.hasPrefix("/") else { throw AugmaPluginError.invalidPackage }
    let relative = String(path.dropFirst())
    guard AugmaPluginManifest.validPath(relative), package.files.contains(relative) else { throw AugmaPluginError.invalidPackage }
    return relative
  }
}
