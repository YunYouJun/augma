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

  func testFailuresReportCodesThePageTranslates() {
    XCTAssertEqual(DeepSeekCommandInterpreter.Failure.invalidKey.code, "deepseekInvalidKey")
    XCTAssertEqual(DeepSeekCommandInterpreter.Failure.http(503).code, "deepseekHttp")
    XCTAssertEqual(DeepSeekCommandInterpreter.Failure.http(503).detail, "503")
    XCTAssertNil(DeepSeekCommandInterpreter.Failure.rateLimited.detail)
  }

  @MainActor
  func testRecognitionLocaleFollowsThePageLanguage() {
    XCTAssertEqual(SpeechCommandRecognizer.recognitionLocale(for: "ja-JP").identifier, "ja-JP")
    XCTAssertEqual(SpeechCommandRecognizer.recognitionLocale(for: "en-US").identifier, "en-US")
    XCTAssertEqual(SpeechCommandRecognizer.recognitionLocale(for: "zh-CN").identifier, "zh-CN")
    XCTAssertEqual(SpeechCommandRecognizer.recognitionLocale(for: nil).identifier, "zh-CN")
    XCTAssertEqual(SpeechCommandRecognizer.recognitionLocale(for: "fr-FR").identifier, "zh-CN")
  }

  private func response(_ content: String, finish: String = "stop") -> Data {
    try! JSONSerialization.data(withJSONObject: [
      "choices": [["finish_reason": finish, "message": ["content": content]]],
    ])
  }
}
