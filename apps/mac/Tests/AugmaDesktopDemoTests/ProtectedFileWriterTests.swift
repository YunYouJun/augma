import Foundation
import XCTest
@testable import AugmaDesktopDemo

// Only temporary fixture bytes use ordinary atomic writes. The production protection request
// is still passed through the boundary, and its flags are checked independently below.
extension ProtectedFileWriter {
  static var temporaryFixture: Self {
    Self { data, url, _ in try data.write(to: url, options: .atomic) }
  }
}

final class ProtectedFileWriterTests: XCTestCase {
  func testPersistenceRequestsAtomicWritesAndTheOriginalDataProtectionClass() throws {
    let expected = Data("fixture".utf8)
    let url = FileManager.default.temporaryDirectory.appending(path: "augma-writer-\(UUID()).json")
    let attempts = WriteAttempts()
    let writer = ProtectedFileWriter { data, destination, options in
      attempts.record()
      XCTAssertEqual(data, expected)
      XCTAssertEqual(destination, url)
      XCTAssertEqual(options, [.atomic, .completeFileProtectionUnlessOpen])
    }
    try writer.write(expected, to: url)
    XCTAssertEqual(attempts.count, 1)
  }

  func testUnavailableKeybagPropagatesWithoutRetryingWithWeakerProtection() {
    let attempts = WriteAttempts()
    let writer = ProtectedFileWriter { _, _, options in
      attempts.record()
      XCTAssertEqual(options, [.atomic, .completeFileProtectionUnlessOpen])
      throw POSIXError(.EPERM)
    }
    XCTAssertThrowsError(try writer.write(Data(), to: URL(fileURLWithPath: "/fixture/receipt.json"))) {
      XCTAssertEqual(($0 as? POSIXError)?.code, .EPERM)
    }
    XCTAssertEqual(attempts.count, 1)
  }
}

private final class WriteAttempts: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  var count: Int { lock.withLock { value } }
  func record() { lock.withLock { value += 1 } }
}
