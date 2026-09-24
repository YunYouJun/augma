import Foundation
import XCTest
@testable import AugmaDesktopDemo

final class DeepSeekCommandInterpreterTests: XCTestCase {
  func testParsesAllowedCommand() throws {
    XCTAssertEqual(try DeepSeekCommandInterpreter.parseResponse(response("{\"command\":\"weather\"}")), "weather")
  }

  func testAcceptsNoMatchingCommand() throws {
    XCTAssertNil(try DeepSeekCommandInterpreter.parseResponse(response("{\"command\":null}")))
  }

  func testRejectsUnknownCommandAndExtraFields() {
    XCTAssertThrowsError(try DeepSeekCommandInterpreter.parseResponse(response("{\"command\":\"deleteFiles\"}")))
    XCTAssertThrowsError(try DeepSeekCommandInterpreter.parseResponse(response("{\"command\":\"weather\",\"path\":\"/tmp\"}")))
  }

  func testRejectsTruncatedResponse() {
    XCTAssertThrowsError(try DeepSeekCommandInterpreter.parseResponse(response("{\"command\":\"weather\"}", finish: "length")))
  }

  private func response(_ content: String, finish: String = "stop") -> Data {
    try! JSONSerialization.data(withJSONObject: [
      "choices": [["finish_reason": finish, "message": ["content": content]]],
    ])
  }
}
