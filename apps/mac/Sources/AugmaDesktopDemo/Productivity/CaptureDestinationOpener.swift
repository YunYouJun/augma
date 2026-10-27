import AppKit

@MainActor
struct CaptureDestinationOpener {
  enum Result: Equatable { case application, website }
  var applicationURL: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
  var openApplication: (URL) async throws -> Void = { url in
    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
  }
  var openWebsite: (URL) -> Bool = { NSWorkspace.shared.open($0) }

  func open(_ destination: CaptureDestination) async throws -> Result {
    let bundleID = destination == .microsoftToDo ? "com.microsoft.to-do-mac" : "com.apple.Notes"
    if let url = applicationURL(bundleID) {
      do {
        try await openApplication(url)
        return .application
      } catch {
        if destination == .appleNotes { throw error }
      }
    }
    if destination == .microsoftToDo, openWebsite(URL(string: "https://to-do.office.com/tasks/")!) {
      return .website
    }
    throw CaptureError.message(String(format: String(localized: "无法打开 %@，请检查是否已安装。"), destination.title))
  }
}
