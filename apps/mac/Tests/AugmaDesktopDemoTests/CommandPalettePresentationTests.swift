import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class CommandPalettePresentationTests: XCTestCase {
  func testGlassLifecycleReservesAndReleasesTheWindowAtTheRightTime() throws {
    let animations = DeferredPaletteAnimations()
    var windowExpanded = false
    let presentation = CommandPalettePresentation(animate: animations.animate,
      prepareExpansion: { windowExpanded = true }, finishCollapse: { windowExpanded = false })
    presentation.show(reduceMotion: false)
    XCTAssertTrue(presentation.visible)
    XCTAssertFalse(presentation.expanded)
    try XCTUnwrap(animations.completions.first)()
    XCTAssertTrue(presentation.expanded)
    XCTAssertTrue(windowExpanded)
    presentation.setExpanded(false, reduceMotion: false)
    XCTAssertTrue(windowExpanded, "Keep space for the collapsing glass")
    try XCTUnwrap(animations.completions.last)()
    XCTAssertFalse(windowExpanded, "The compact capsule must not intercept clicks below it")
    presentation.setExpanded(true, reduceMotion: false)
    var closed = false
    presentation.hide(reduceMotion: false) { closed = true }
    XCTAssertTrue(presentation.visible)
    XCTAssertFalse(closed)
    try XCTUnwrap(animations.completions.last)()
    XCTAssertFalse(presentation.visible)
    XCTAssertFalse(windowExpanded)
    XCTAssertFalse(closed)
    try XCTUnwrap(animations.completions.last)()
    XCTAssertTrue(closed)
  }

  func testReopeningIgnoresStaleResizeAndCloseCompletions() throws {
    for stage in [Interruption.collapse, .hide, .dematerialize] {
      let animations = DeferredPaletteAnimations()
      var windowExpanded = false
      let presentation = CommandPalettePresentation(animate: animations.animate,
        prepareExpansion: { windowExpanded = true }, finishCollapse: { windowExpanded = false })
      presentation.show(reduceMotion: true)
      var closed = false
      if stage == .collapse { presentation.setExpanded(false, reduceMotion: false) }
      else { presentation.hide(reduceMotion: false) { closed = true } }
      if stage == .dematerialize { try XCTUnwrap(animations.completions.last)() }
      let staleCompletion = try XCTUnwrap(animations.completions.last)
      presentation.show(reduceMotion: false)
      staleCompletion()
      if !presentation.expanded { try XCTUnwrap(animations.completions.last)() }
      XCTAssertFalse(closed)
      XCTAssertTrue(presentation.visible)
      XCTAssertTrue(presentation.expanded)
      XCTAssertTrue(windowExpanded)
    }
  }

  func testExplicitCollapseDuringEntranceKeepsResultsHidden() throws {
    let animations = DeferredPaletteAnimations()
    let presentation = CommandPalettePresentation(animate: animations.animate)
    presentation.show(reduceMotion: false)
    let entrance = try XCTUnwrap(animations.completions.first)
    presentation.setExpanded(false, reduceMotion: false)
    entrance()
    XCTAssertFalse(presentation.expanded)
  }

  func testReducedMotionCompletesImmediatelyWithoutSchedulingAnimation() {
    let animations = DeferredPaletteAnimations()
    let presentation = CommandPalettePresentation(animate: animations.animate)
    presentation.show(reduceMotion: true)
    XCTAssertTrue(presentation.visible)
    XCTAssertTrue(presentation.expanded)
    var closed = false
    presentation.hide(reduceMotion: true) { closed = true }
    XCTAssertTrue(closed)
    XCTAssertFalse(presentation.visible)
    XCTAssertFalse(presentation.expanded)
    XCTAssertTrue(animations.completions.isEmpty)
  }

  private enum Interruption { case collapse, hide, dematerialize }
}

@MainActor
private final class DeferredPaletteAnimations {
  var completions: [@MainActor () -> Void] = []

  func animate(_ animation: Animation, changes: () -> Void, completion: @escaping @MainActor () -> Void) {
    changes()
    completions.append(completion)
  }
}
