import Foundation

/// Keeps protected atomic writes at the OS boundary so fixture I/O does not depend on the login keybag.
struct ProtectedFileWriter: Sendable {
  typealias Write = @Sendable (Data, URL, Data.WritingOptions) throws -> Void
  private let writeData: Write

  init(writeData: @escaping Write = { data, url, options in try data.write(to: url, options: options) }) {
    self.writeData = writeData
  }

  func write(_ data: Data, to url: URL) throws {
    try writeData(data, url, [.atomic, .completeFileProtectionUnlessOpen])
  }
}
