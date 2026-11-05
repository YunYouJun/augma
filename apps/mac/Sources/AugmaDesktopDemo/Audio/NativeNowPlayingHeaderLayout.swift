import SwiftUI

/// Proposes a real text-column width instead of testing an unwrapped ideal size.
/// The 400-point immersive panel has room for compact artwork and all controls.
struct NativeNowPlayingHeaderLayout: Layout {
  private let spacing: CGFloat = 16
  private let compactArtwork: CGFloat = 96
  private let regularArtwork: CGFloat = 128
  private let minimumMetadataWidth: CGFloat = 176

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard subviews.count == 2 else { return .zero }
    return measurements(width: proposal.width, subviews: subviews).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard subviews.count == 2 else { return }
    let layout = measurements(width: bounds.width, subviews: subviews)
    subviews[0].place(at: bounds.origin, anchor: .topLeading,
                      proposal: ProposedViewSize(width: layout.artwork, height: layout.artwork))
    subviews[1].place(at: CGPoint(x: bounds.minX + layout.metadataOrigin.x, y: bounds.minY + layout.metadataOrigin.y),
                      anchor: .topLeading, proposal: ProposedViewSize(width: layout.metadataWidth, height: nil))
  }

  private struct Measurements {
    let size: CGSize
    let artwork: CGFloat
    let metadataWidth: CGFloat
    let metadataOrigin: CGPoint
  }

  private func measurements(width proposedWidth: CGFloat?, subviews: Subviews) -> Measurements {
    let width = proposedWidth.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 400
    let horizontal = width >= compactArtwork + spacing + minimumMetadataWidth
    let artwork = horizontal ? (width >= 400 ? regularArtwork : compactArtwork) : min(regularArtwork, width)
    let metadataWidth = horizontal ? width - artwork - spacing : width
    let metadata = subviews[1].sizeThatFits(ProposedViewSize(width: metadataWidth, height: nil))
    return Measurements(
      size: CGSize(width: width, height: horizontal ? max(artwork, metadata.height) : artwork + spacing + metadata.height),
      artwork: artwork,
      metadataWidth: metadataWidth,
      metadataOrigin: horizontal ? CGPoint(x: artwork + spacing, y: 0) : CGPoint(x: 0, y: artwork + spacing)
    )
  }
}
