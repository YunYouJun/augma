import XCTest
@testable import AugmaDesktopDemo

final class ImmersiveLayoutTests: XCTestCase {
  func testChromeFitsScreenAndLeavesContentClearOnSmallAndLargeDisplays() {
    for size in [CGSize(width: 640, height: 480), CGSize(width: 1280, height: 720), CGSize(width: 1728, height: 1080)] {
      let screen = CGRect(origin: .zero, size: size)
      let content = ImmersiveLayout.content(in: size)
      // Content is SwiftUI top-left geometry; convert it to screen coordinates.
      let converted = CGRect(x: content.minX, y: size.height - content.maxY, width: content.width, height: content.height)
      let chrome = ImmersiveLayout.Chrome.allCases.map { ImmersiveLayout.frame(for: $0, in: screen) }
      for rect in chrome {
        XCTAssertTrue(screen.contains(rect))
        XCTAssertFalse(rect.intersects(converted), "HUD controls must not overlap the browser or details")
      }
      for (index, rect) in chrome.enumerated() {
        for other in chrome.dropFirst(index + 1) { XCTAssertFalse(rect.intersects(other)) }
      }
    }
  }

  func testChromeTracksVisibleFrameOnAnotherDisplay() {
    let size = CGSize(width: 1440, height: 850)
    let origin = CGPoint(x: -1440, y: 140)
    for kind in ImmersiveLayout.Chrome.allCases {
      let base = ImmersiveLayout.frame(for: kind, in: CGRect(origin: .zero, size: size))
      let moved = ImmersiveLayout.frame(for: kind, in: CGRect(origin: origin, size: size))
      XCTAssertEqual(moved, base.offsetBy(dx: origin.x, dy: origin.y))
    }
  }
}
