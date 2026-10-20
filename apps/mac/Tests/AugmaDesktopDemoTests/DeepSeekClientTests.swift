import Foundation
import XCTest
@testable import AugmaDesktopDemo

final class DeepSeekClientTests: XCTestCase {
  func testReturnsTheMessageContentForThePageToParse() throws {
    XCTAssertEqual(try DeepSeekClient.parseResponse(response("{\"reply\":\"hi\",\"command\":null}")), "{\"reply\":\"hi\",\"command\":null}")
  }

  func testRejectsTruncatedOrEmptyResponse() {
    XCTAssertThrowsError(try DeepSeekClient.parseResponse(response("{\"reply\":\"hi\"", finish: "length")))
    XCTAssertThrowsError(try DeepSeekClient.parseResponse(response("")))
  }

  func testForwardsOnlyPlainChatMessagesEndingWithTheQuestion() throws {
    let messages: [[String: Any]] = [
      ["role": "system", "content": "prompt"],
      ["role": "user", "content": "earlier"],
      ["role": "assistant", "content": "{\"reply\":\"ok\",\"command\":null}"],
      ["role": "user", "content": "question"],
    ]
    XCTAssertEqual(try DeepSeekClient.validate(messages).count, 4)
    XCTAssertThrowsError(try DeepSeekClient.validate("question"))
    XCTAssertThrowsError(try DeepSeekClient.validate([["role": "user", "content": "question"]]))
    XCTAssertThrowsError(try DeepSeekClient.validate(Array(messages.dropLast())))
    XCTAssertThrowsError(try DeepSeekClient.validate([["role": "tool", "content": "x"], ["role": "user", "content": "q"]]))
    XCTAssertThrowsError(try DeepSeekClient.validate([["role": "system", "content": "p", "name": "x"], ["role": "user", "content": "q"]]))
    XCTAssertThrowsError(try DeepSeekClient.validate([["role": "system", "content": "p"], ["role": "user", "content": ""]]))
    let long = String(repeating: "x", count: DeepSeekClient.maxCharacters)
    XCTAssertThrowsError(try DeepSeekClient.validate([["role": "system", "content": long], ["role": "user", "content": "q"]]))
    let many = Array(repeating: ["role": "user", "content": "q"], count: DeepSeekClient.maxMessages + 1)
    XCTAssertThrowsError(try DeepSeekClient.validate(many))
  }

  func testFailuresReportCodesThePageTranslates() {
    XCTAssertEqual(DeepSeekClient.Failure.invalidKey.code, "deepseekInvalidKey")
    XCTAssertEqual(DeepSeekClient.Failure.invalidInput.code, "deepseekInvalidInput")
    XCTAssertEqual(DeepSeekClient.Failure.http(503).code, "deepseekHttp")
    XCTAssertEqual(DeepSeekClient.Failure.http(503).detail, "503")
    XCTAssertNil(DeepSeekClient.Failure.rateLimited.detail)
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
