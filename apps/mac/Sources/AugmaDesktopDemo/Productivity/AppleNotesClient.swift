import AppKit
import CoreServices

struct AppleNotesClient: Sendable {
  @MainActor
  func prepare() async throws {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") else {
      throw CaptureError.message(String(localized: "找不到 macOS 备忘录，请确认应用已安装。"))
    }
    // A normal launch/reopen event initializes Notes before its first scripting request.
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    // The system consent dialog can take arbitrarily long. It must not consume the write timeout.
    let status = await Task.detached {
      let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.Notes")
      return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
    }.value
    if status == errAEEventNotPermitted || status == errAEEventWouldRequireUserConsent {
      throw CaptureError.message(String(localized: "请在系统设置 → 隐私与安全性 → 自动化中允许 Augma 控制备忘录，然后重试。"))
    }
    guard status == noErr else {
      throw CaptureError.message(String(format: String(localized: "备忘录尚未准备好（%@），请打开备忘录后重试。"), String(status)))
    }
  }

  // User content travels through stdin, never through script source, arguments or temporary files.
  static let createScript = """
  use framework "Foundation"
  use scripting additions
  on run
    set inputData to current application's NSFileHandle's fileHandleWithStandardInput()'s readDataToEndOfFile()
    set noteBody to (current application's NSString's alloc()'s initWithData:inputData encoding:(current application's NSUTF8StringEncoding)) as text
    with timeout of 45 seconds
      tell application id "com.apple.Notes"
        set targetFolder to default folder of default account
        set createdNote to make new note at targetFolder with properties {body:noteBody}
        return id of createdNote
      end tell
    end timeout
  end run
  """

  static func html(_ text: String) -> String {
    let escaped = text.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
      .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    return escaped.components(separatedBy: "\n").map { "<div>\($0.isEmpty ? "<br>" : $0)</div>" }.joined()
  }

  func create(text: String) async throws -> CaptureReceipt {
    try await Task.detached(priority: .userInitiated) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
      process.arguments = ["-e", Self.createScript]
      let input = Pipe(), output = Pipe(), errors = Pipe()
      process.standardInput = input
      process.standardOutput = output
      process.standardError = errors
      try process.run()
      let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
      DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: deadline)
      defer { deadline.cancel() }
      do {
        try input.fileHandleForWriting.write(contentsOf: Data(Self.html(text).utf8))
        try input.fileHandleForWriting.close()
      } catch {
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
        throw CaptureError.uncertain
      }
      let data = output.fileHandleForReading.readDataToEndOfFile()
      let errorData = errors.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else {
        let message = String(decoding: errorData, as: UTF8.self)
        if message.contains("-1743") {
          throw CaptureError.message(String(localized: "请在系统设置 → 隐私与安全性 → 自动化中允许 Augma 控制备忘录，然后重试。"))
        }
        if message.contains("-1728") {
          throw CaptureError.message(String(localized: "未找到备忘录默认文件夹。请先打开备忘录并配置默认账户。"))
        }
        // Apple Events can time out after Notes has created the note.
        throw CaptureError.uncertain
      }
      let id = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !id.isEmpty else { throw CaptureError.uncertain }
      return CaptureReceipt(destination: .appleNotes, remoteID: id)
    }.value
  }
}
