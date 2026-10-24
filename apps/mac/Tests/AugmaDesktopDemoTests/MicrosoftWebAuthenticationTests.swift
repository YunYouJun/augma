import AuthenticationServices
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class MicrosoftWebAuthenticationTests: XCTestCase {
  func testSuccessfulCallbackCanArriveOnBackgroundQueue() async throws {
    let request = try MicrosoftOAuthRequest()
    let url = try XCTUnwrap(URL(string: "\(MicrosoftOAuthRequest.redirectURI)?state=\(request.state)&code=accepted"))
    let callback: URL = try await withCheckedThrowingContinuation { continuation in
      let handler = MicrosoftWebAuthentication.completionHandler(continuation)
      DispatchQueue.global().async {
        dispatchPrecondition(condition: .notOnQueue(.main))
        handler(url, nil)
      }
    }
    MainActor.assertIsolated()
    XCTAssertEqual(try request.code(from: callback), "accepted")
  }

  func testCancellationAndSessionErrorsCanArriveOnBackgroundQueue() async throws {
    for code in [ASWebAuthenticationSessionError.Code.canceledLogin, .presentationContextInvalid] {
      let expected = NSError(domain: ASWebAuthenticationSessionErrorDomain, code: code.rawValue)
      do {
        let _: URL = try await withCheckedThrowingContinuation { continuation in
          let handler = MicrosoftWebAuthentication.completionHandler(continuation)
          DispatchQueue.global().async {
            dispatchPrecondition(condition: .notOnQueue(.main))
            handler(nil, expected)
          }
        }
        XCTFail("A failed authentication callback must throw")
      } catch {
        MainActor.assertIsolated()
        XCTAssertEqual((error as NSError).domain, expected.domain)
        XCTAssertEqual((error as NSError).code, expected.code)
      }
    }
  }

  func testEmptyCallbackReportsFailureOnBackgroundQueue() async {
    do {
      let _: URL = try await withCheckedThrowingContinuation { continuation in
        let handler = MicrosoftWebAuthentication.completionHandler(continuation)
        DispatchQueue.global().async {
          dispatchPrecondition(condition: .notOnQueue(.main))
          handler(nil, nil)
        }
      }
      XCTFail("An empty authentication callback must throw")
    } catch {
      MainActor.assertIsolated()
      guard case CaptureError.message(let message) = error else {
        return XCTFail("Unexpected authentication error: \(error)")
      }
      XCTAssertEqual(message, String(localized: "Microsoft 登录未完成或未获授权。"))
    }
  }
}
