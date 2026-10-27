import AppKit

enum ApplicationCleanup {
  /// Request normal termination from the same app bundle. Never signal helpers or force quit.
  static func matches(_ identity: ApplicationMemoryIdentity, pid: Int32, bundlePath: String,
                      launchedAt: Date?, ownPID: Int32) -> Bool {
    identity.processIdentifier == pid && pid != ownPID && identity.bundlePath == bundlePath
      && identity.launchedAt != nil && identity.launchedAt == launchedAt
  }

  @MainActor static func requestQuit(_ identity: ApplicationMemoryIdentity) -> Bool {
    guard let app = runningApplication(identity) else { return false }
    return app.terminate()
  }

  @MainActor static func canRequestQuit(_ identity: ApplicationMemoryIdentity) -> Bool {
    runningApplication(identity) != nil
  }

  @MainActor private static func runningApplication(_ identity: ApplicationMemoryIdentity) -> NSRunningApplication? {
    guard let app = NSRunningApplication(processIdentifier: identity.processIdentifier),
      let path = app.bundleURL?.path,
      matches(identity, pid: app.processIdentifier, bundlePath: path, launchedAt: app.launchDate,
              ownPID: ProcessInfo.processInfo.processIdentifier),
      app.activationPolicy == .regular, app.bundleIdentifier != "com.apple.finder", !app.isTerminated else { return nil }
    return app
  }
}
