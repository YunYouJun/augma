import AppKit
import Combine

@MainActor
protocol InstalledApplicationClient: AnyObject {
  var onChange: (() -> Void)? { get set }
  func inspect(_ url: URL) throws -> InstalledApplication
  func resolve(_ building: ApplicationBuilding) -> InstalledApplication?
  func suggestions() -> [InstalledApplication]
  func icon(for application: InstalledApplication) -> NSImage
  func runningStates() -> [String: ApplicationRunState]
  func open(_ application: InstalledApplication) async throws
  func startObserving()
  func stopObserving()
}

@MainActor
final class SystemInstalledApplicationClient: InstalledApplicationClient {
  var onChange: (() -> Void)?
  private var observations: [AnyCancellable] = []

  func inspect(_ url: URL) throws -> InstalledApplication {
    let url = url.resolvingSymlinksInPath().standardizedFileURL
    let manifest = url.appending(path: "Contents/Info.plist")
    guard url.isFileURL, url.pathExtension.lowercased() == "app",
          let data = try? Data(contentsOf: manifest), data.count < 1024 * 1024,
          let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let id = info["CFBundleIdentifier"] as? String,
          !id.isEmpty, id.count <= 255, !id.contains(where: { $0.isWhitespace || $0.isNewline }),
          let executable = info["CFBundleExecutable"] as? String, !executable.isEmpty,
          !executable.contains("/"), executable != ".", executable != "..",
          FileManager.default.isExecutableFile(atPath: url.appending(path: "Contents/MacOS").appending(path: executable).path)
    else { throw ApplicationDistrictError.notApplication }
    let name = (Bundle(url: url)?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
      ?? (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String)
      ?? url.deletingPathExtension().lastPathComponent
    return InstalledApplication(id: id, name: String(name.prefix(80)), path: url.path)
  }

  func resolve(_ building: ApplicationBuilding) -> InstalledApplication? {
    if let app = try? inspect(URL(fileURLWithPath: building.applicationPath)), app.id == building.id { return app }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: building.id),
          let app = try? inspect(url), app.id == building.id else { return nil }
    return app
  }

  func suggestions() -> [InstalledApplication] {
    ["com.microsoft.VSCode", "com.google.Chrome", "com.apple.Safari", "com.apple.Terminal"].compactMap { id in
      guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
            let app = try? inspect(url), app.id == id else { return nil }
      return app
    }
  }

  func icon(for application: InstalledApplication) -> NSImage { NSWorkspace.shared.icon(forFile: application.path) }

  func runningStates() -> [String: ApplicationRunState] {
    var result: [String: ApplicationRunState] = [:]
    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    for app in NSWorkspace.shared.runningApplications where !app.isTerminated {
      guard let id = app.bundleIdentifier else { continue }
      result[id] = frontmost == id ? .frontmost : .running
    }
    return result
  }

  func open(_ application: InstalledApplication) async throws {
    // Revalidate on every click, including when an app at the saved path was replaced.
    let checked = try inspect(URL(fileURLWithPath: application.path))
    guard checked.id == application.id else { throw ApplicationDistrictError.missingApplication }
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: checked.id).first(where: { !$0.isTerminated }) {
      NSApp.yieldActivation(to: running)
      if running.activate(from: .current, options: [.activateAllWindows]) { return }
    }
    // Inactive panels may not transfer activation. A normal open request also
    // restores the existing app without creating a second application instance.
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = false
    _ = try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: checked.path), configuration: configuration)
  }

  func startObserving() {
    guard observations.isEmpty else { return }
    for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                 NSWorkspace.didActivateApplicationNotification, NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
      NSWorkspace.shared.notificationCenter.publisher(for: name).receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.onChange?() }.store(in: &observations)
    }
  }

  func stopObserving() { observations.removeAll(); onChange = nil }
}
