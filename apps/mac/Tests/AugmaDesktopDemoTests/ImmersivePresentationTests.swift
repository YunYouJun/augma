import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ImmersivePresentationTests: XCTestCase {
  func testLinkStartPlaysOnceAcrossHidingAndLeavingImmersiveMode() {
    let fades = DeferredImmersiveFades()
    let presentation = ImmersivePresentation(animate: fades.animate)
    var entrances: [Bool] = []
    presentation.show(windows: [], reduceMotion: false) { entrances.append($0) }
    presentation.hide(windows: [], reduceMotion: false) {}
    fades.requests.last?.completion()
    presentation.show(windows: [], reduceMotion: false) { entrances.append($0) }
    presentation.cancel()
    presentation.show(windows: [], reduceMotion: false) { entrances.append($0) }

    XCTAssertEqual(entrances, [true, false, false])
    XCTAssertEqual(fades.requests.map(\.duration), [0.1, 0.14, 0.14])
    let nextLaunch = ImmersivePresentation(animate: fades.animate)
    nextLaunch.show(windows: [], reduceMotion: false) { XCTAssertTrue($0) }
  }

  func testHideKeepsSceneMountedUntilFadeCompletes() throws {
    let fades = DeferredImmersiveFades()
    let presentation = ImmersivePresentation(animate: fades.animate)
    var mounted = true
    var focusRestored = false
    presentation.show(windows: [], reduceMotion: false) { _ in }
    presentation.hide(windows: [], reduceMotion: false) {
      mounted = false
      focusRestored = true
    }
    XCTAssertTrue(mounted)
    XCTAssertFalse(focusRestored)
    let hide = try XCTUnwrap(fades.requests.last)
    XCTAssertEqual(hide.opacity, 0)
    hide.completion()
    XCTAssertFalse(mounted)
    XCTAssertTrue(focusRestored)
  }

  func testRapidRevealHideRevealIgnoresOutOfOrderHideCompletions() throws {
    let fades = DeferredImmersiveFades()
    let presentation = ImmersivePresentation(animate: fades.animate)
    var cleanupCount = 0
    presentation.show(windows: [], reduceMotion: false) { _ in }
    presentation.hide(windows: [], reduceMotion: false) { cleanupCount += 1 }
    let firstHide = try XCTUnwrap(fades.requests.last)
    presentation.show(windows: [], reduceMotion: false) { XCTAssertFalse($0) }
    presentation.hide(windows: [], reduceMotion: false) { cleanupCount += 1 }
    let secondHide = try XCTUnwrap(fades.requests.last)
    presentation.show(windows: [], reduceMotion: false) { XCTAssertFalse($0) }

    secondHide.completion()
    firstHide.completion()
    XCTAssertEqual(cleanupCount, 0, "An old fade must not unmount the new scene or restore old focus")
    presentation.hide(windows: [], reduceMotion: false) { cleanupCount += 1 }
    fades.requests.last?.completion()
    XCTAssertEqual(cleanupCount, 1)
  }

  func testLeavingImmersiveModeInvalidatesPendingHideCleanup() {
    let fades = DeferredImmersiveFades()
    let presentation = ImmersivePresentation(animate: fades.animate)
    var cleanedUp = false
    presentation.show(windows: [], reduceMotion: false) { _ in }
    presentation.hide(windows: [], reduceMotion: false) { cleanedUp = true }
    presentation.cancel()
    fades.requests.last?.completion()
    XCTAssertFalse(cleanedUp)
  }

  func testReducedMotionSkipsIntroAndFadesWithoutDelayingCleanup() {
    let fades = DeferredImmersiveFades()
    let presentation = ImmersivePresentation(animate: fades.animate)
    presentation.show(windows: [], reduceMotion: true) { XCTAssertFalse($0) }
    var cleanedUp = false
    presentation.hide(windows: [], reduceMotion: true) { cleanedUp = true }
    XCTAssertTrue(cleanedUp)
    XCTAssertTrue(fades.requests.isEmpty)

    // Changing the preference later must not play a deferred startup animation.
    presentation.show(windows: [], reduceMotion: false) { XCTAssertFalse($0) }
    XCTAssertEqual(fades.requests.last?.duration, 0.14)
  }
}

@MainActor
private final class DeferredImmersiveFades {
  struct Request {
    let opacity: CGFloat
    let duration: TimeInterval
    let completion: @MainActor () -> Void
  }
  var requests: [Request] = []

  func animate(_ windows: [NSWindow], opacity: CGFloat, duration: TimeInterval,
               completion: @escaping @MainActor () -> Void) {
    requests.append(Request(opacity: opacity, duration: duration, completion: completion))
  }
}
