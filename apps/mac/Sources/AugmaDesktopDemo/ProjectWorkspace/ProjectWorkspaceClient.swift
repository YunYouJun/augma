import AppKit

@MainActor
protocol ProjectWorkspaceClient {
  func captureFolder(_ url: URL) throws -> ProjectFolder
  func defaultApplication(_ id: String) -> ProjectApplication?
  func inspectApplication(_ url: URL, expectedID: String) throws -> ProjectApplication
  func openEditor(folder: ProjectFolder, application: ProjectApplication?) async throws
  func openWebsite(_ url: URL, application: ProjectApplication?) async throws
  func revealFolder(_ folder: ProjectFolder) throws
}

@MainActor
final class SystemProjectWorkspaceClient: ProjectWorkspaceClient {
  private let applications = SystemInstalledApplicationClient()

  func captureFolder(_ url: URL) throws -> ProjectFolder {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    try validateFolder(url)
    if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
      return ProjectFolder(bookmark: bookmark, displayPath: url.path, securityScoped: true)
    }
    // Unsandboxed builds can use ordinary persistent bookmarks. Never substitute
    // the display path when resolving a stale or missing bookmark.
    let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    return ProjectFolder(bookmark: bookmark, displayPath: url.path, securityScoped: false)
  }

  func defaultApplication(_ id: String) -> ProjectApplication? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
    return try? inspectApplication(url, expectedID: id)
  }

  func inspectApplication(_ url: URL, expectedID: String) throws -> ProjectApplication {
    let app = try applications.inspect(url)
    guard app.id == expectedID else { throw ProjectWorkspaceError.wrongApplication }
    return ProjectApplication(app)
  }

  func openEditor(folder: ProjectFolder, application: ProjectApplication?) async throws {
    let access = try resolveFolder(folder)
    defer { access.release() }
    let app = try resolveApplication(application, expectedID: "com.microsoft.VSCode")
    try Task.checkCancellation()
    try await ProjectEditorProcess().open(applicationURL: URL(fileURLWithPath: app.path), folderURL: access.url)
  }

  func openWebsite(_ url: URL, application: ProjectApplication?) async throws {
    guard try ProjectWebsite.parse(url.absoluteString) == [url.absoluteString] else { throw ProjectWorkspaceError.invalidWebsite }
    let app = try resolveApplication(application, expectedID: "com.google.Chrome")
    try Task.checkCancellation()
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = false
    _ = try await NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: app.path), configuration: configuration)
  }

  func revealFolder(_ folder: ProjectFolder) throws {
    let access = try resolveFolder(folder)
    defer { access.release() }
    NSWorkspace.shared.activateFileViewerSelecting([access.url])
  }

  func resolveFolder(_ folder: ProjectFolder) throws -> (url: URL, release: () -> Void) {
    var stale = false
    var options: URL.BookmarkResolutionOptions = [.withoutUI, .withoutMounting]
    if folder.securityScoped { options.insert(.withSecurityScope) }
    guard let url = try? URL(resolvingBookmarkData: folder.bookmark, options: options, relativeTo: nil, bookmarkDataIsStale: &stale), !stale else {
      throw ProjectWorkspaceError.folderUnavailable
    }
    let accessing = url.startAccessingSecurityScopedResource()
    do { try validateFolder(url) }
    catch { if accessing { url.stopAccessingSecurityScopedResource() }; throw error }
    return (url, { if accessing { url.stopAccessingSecurityScopedResource() } })
  }

  private func validateFolder(_ url: URL) throws {
    guard url.isFileURL, let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
          values.isDirectory == true, values.isPackage != true,
          FileManager.default.isReadableFile(atPath: url.path) else { throw ProjectWorkspaceError.folderUnavailable }
  }

  private func resolveApplication(_ application: ProjectApplication?, expectedID: String) throws -> InstalledApplication {
    guard let application, application.id == expectedID, let resolved = applications.resolve(application.building),
          resolved.id == expectedID else { throw ProjectWorkspaceError.applicationUnavailable }
    return resolved
  }
}
