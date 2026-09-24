import Foundation
import UniformTypeIdentifiers
import WebKit

final class DemoResourceSchemeHandler: NSObject, WKURLSchemeHandler {
  static let scheme = "augma-demo"
  static let startURL = URL(string: "augma-demo://app/index.html")!

  private let rootURL: URL

  init(rootURL: URL) {
    self.rootURL = rootURL.standardizedFileURL
  }

  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    guard let url = urlSchemeTask.request.url, url.host == "app" else {
      urlSchemeTask.didFailWithError(URLError(.badURL))
      return
    }

    let path = url.path == "/" ? "/index.html" : url.path
    let fileURL = rootURL.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
    guard fileURL.path.hasPrefix(rootURL.path + "/"),
          let data = try? Data(contentsOf: fileURL) else {
      urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
      return
    }

    let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
    urlSchemeTask.didReceive(response)
    urlSchemeTask.didReceive(data)
    urlSchemeTask.didFinish()
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
