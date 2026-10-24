import Dispatch
import Speech
import XCTest
@testable import AugmaDesktopDemo

final class SpeechCommandRecognizerTests: XCTestCase {
  @MainActor
  func testAuthorizationCallbackCanArriveOnBackgroundQueue() async {
    let statuses: [SFSpeechRecognizerAuthorizationStatus] = [.authorized, .denied, .restricted, .notDetermined]
    for status in statuses {
      let result = await SpeechCommandRecognizer.requestSpeechAuthorization { completion in
        DispatchQueue.global(qos: .default).async {
          dispatchPrecondition(condition: .notOnQueue(.main))
          completion(status)
        }
      }
      MainActor.assertIsolated()
      XCTAssertEqual(result, status)
    }
  }

  @MainActor
  func testAuthorizationCallbackCanCompleteSynchronously() async {
    let result = await SpeechCommandRecognizer.requestSpeechAuthorization { completion in
      completion(.authorized)
    }
    MainActor.assertIsolated()
    XCTAssertEqual(result, .authorized)
  }
}
