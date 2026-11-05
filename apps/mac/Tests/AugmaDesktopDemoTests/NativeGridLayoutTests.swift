import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeGridLayoutTests: XCTestCase {
  func testFixedColumnsIncludeEveryRowAndUseTheTallestCellInEachRow() throws {
    let grid = NativeGridLayout(columns: .fixed(2), spacing: 12) {
      ForEach([20, 40, 60, 80, 100], id: \.self) { height in
        Color.blue.frame(height: CGFloat(height))
      }
    }
    let size = try renderedSize(grid, width: 332)
    XCTAssertEqual(size.width, 332, accuracy: 0.5)
    XCTAssertEqual(size.height, 40 + 80 + 100 + 24, accuracy: 0.5)
  }

  func testAdaptiveColumnsWrapAtMinimumWidthWithoutLosingTheLastRow() throws {
    let grid = NativeGridLayout(columns: .adaptive(minimum: 160), spacing: 12) {
      ForEach(0..<7) { _ in Color.blue.frame(height: 40) }
    }
    for (width, height) in [(159, 352), (331, 352), (332, 196), (504, 144), (800, 92)] {
      let size = try renderedSize(grid, width: CGFloat(width))
      XCTAssertEqual(size.width, CGFloat(width), accuracy: 0.5)
      XCTAssertEqual(size.height, CGFloat(height), accuracy: 0.5, "Incorrect wrapping at width \(width)")
    }
  }

  func testEmptyAndZeroWidthProposalsReturnFiniteSizes() throws {
    let empty = NativeGridLayout(columns: .adaptive(minimum: 160)) { EmptyView() }
    let emptySize = try renderedSize(empty.padding(1), width: 332)
    XCTAssertEqual(emptySize.height, 2, accuracy: 0.5)
    let narrow = NativeGridLayout(columns: .fixed(2)) {
      Color.blue.frame(height: 40)
      Color.green.frame(height: 60)
    }
    let narrowSize = try renderedSize(narrow.frame(width: 0).padding(1), width: 2)
    XCTAssertEqual(narrowSize.height, 62, accuracy: 0.5)
  }

  func testResizingAndChangingContentProducesRepeatableFullHeights() throws {
    for count in [7, 20, 7] {
      for width: CGFloat in [332, 800, 332] {
        let grid = NativeGridLayout(columns: .adaptive(minimum: 160), spacing: 12) {
          ForEach(0..<count, id: \.self) { _ in Color.blue.frame(height: 40) }
        }
        let size = try renderedSize(grid, width: width)
        let repeated = try renderedSize(grid, width: width)
        XCTAssertEqual(size, repeated)
        let expected: CGFloat = count == 7 ? (width == 332 ? 196 : 92) : (width == 332 ? 508 : 248)
        XCTAssertEqual(size.height, expected, accuracy: 0.5)
      }
    }
  }

  private func renderedSize<Content: View>(_ content: Content, width: CGFloat) throws -> CGSize {
    let renderer = ImageRenderer(content: content.frame(width: width).background(Color.white))
    return try XCTUnwrap(renderer.nsImage).size
  }
}
