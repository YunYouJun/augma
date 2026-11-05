import SwiftUI

/// Fully measures small grids, including offscreen rows, without geometry-to-state feedback.
struct NativeGridLayout: Layout {
  enum Columns: Sendable {
    case fixed(Int)
    case adaptive(minimum: CGFloat)
  }

  var columns: Columns
  var spacing: CGFloat = NativePageLayout.itemSpacing

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    measurements(width: proposal.width, subviews: subviews).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let grid = measurements(width: bounds.width, subviews: subviews)
    var y = bounds.minY
    for (row, height) in grid.rowHeights.enumerated() {
      for column in 0..<grid.columnCount {
        let index = row * grid.columnCount + column
        guard index < subviews.count else { break }
        subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(column) * (grid.cellWidth + spacing), y: y),
                              anchor: .topLeading, proposal: ProposedViewSize(width: grid.cellWidth, height: nil))
      }
      y += height + spacing
    }
  }

  private struct Measurements {
    var size: CGSize = .zero
    var columnCount = 1
    var cellWidth: CGFloat = 0
    var rowHeights: [CGFloat] = []
  }

  private func measurements(width proposedWidth: CGFloat?, subviews: Subviews) -> Measurements {
    guard !subviews.isEmpty else { return Measurements() }
    let width: CGFloat
    if let proposedWidth, proposedWidth.isFinite {
      width = max(0, proposedWidth)
    } else {
      let idealWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
      switch columns {
      case .fixed(let count): width = idealWidth * CGFloat(max(1, count)) + spacing * CGFloat(max(0, count - 1))
      case .adaptive(let minimum): width = max(minimum, idealWidth)
      }
    }
    let columnCount: Int
    switch columns {
    case .fixed(let count): columnCount = max(1, count)
    case .adaptive(let minimum):
      columnCount = max(1, min(subviews.count, Int((width + spacing) / max(1, minimum + spacing))))
    }
    let cellWidth = max(0, (width - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
    var rowHeights = Array(repeating: CGFloat.zero, count: (subviews.count + columnCount - 1) / columnCount)
    for (index, subview) in subviews.enumerated() {
      let size = subview.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil))
      rowHeights[index / columnCount] = max(rowHeights[index / columnCount], size.height)
    }
    return Measurements(size: CGSize(width: width, height: rowHeights.reduce(0, +) + CGFloat(rowHeights.count - 1) * spacing),
                        columnCount: columnCount, cellWidth: cellWidth, rowHeights: rowHeights)
  }
}
