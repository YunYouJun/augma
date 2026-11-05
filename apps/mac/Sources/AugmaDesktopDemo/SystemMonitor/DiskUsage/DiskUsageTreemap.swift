import SwiftUI

/// Balanced rectangle partitioning. Zero weights have no area; all positive weights keep proportional area.
enum DiskUsageTreemapLayout {
  struct Tile { let index: Int; let frame: CGRect }

  static func tiles(weights: [Double], in bounds: CGRect) -> [Tile] {
    let values = weights.enumerated().filter { $0.element.isFinite && $0.element > 0 }
      .map { (index: $0.offset, weight: $0.element) }
    guard bounds.width > 0, bounds.height > 0 else { return [] }
    func partition(_ items: ArraySlice<(index: Int, weight: Double)>, _ rect: CGRect) -> [Tile] {
      guard let first = items.first else { return [] }
      if items.count == 1 { return [.init(index: first.index, frame: rect)] }
      let total = items.reduce(0) { $0 + $1.weight }
      var sum = 0.0
      var split = items.startIndex + 1
      var best = Double.greatestFiniteMagnitude
      for index in items.indices.dropLast() {
        sum += items[index].weight
        let distance = abs(total / 2 - sum)
        if distance < best { best = distance; split = index + 1 }
      }
      let fraction = items[..<split].reduce(0) { $0 + $1.weight } / total
      if rect.width >= rect.height {
        let width = rect.width * fraction
        return partition(items[..<split], CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
          + partition(items[split...], CGRect(x: rect.minX + width, y: rect.minY, width: rect.width - width, height: rect.height))
      }
      let height = rect.height * fraction
      return partition(items[..<split], CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height))
        + partition(items[split...], CGRect(x: rect.minX, y: rect.minY + height, width: rect.width, height: rect.height - height))
    }
    return partition(values[...], bounds)
  }
}

struct DiskUsageTreemap: View {
  let node: DiskUsageNode
  let metric: DiskUsageMetric
  let select: (DiskUsageNode) -> Void

  private struct Item {
    let node: DiskUsageNode?
    let title: String
    let bytes: UInt64
  }

  private var entries: [Item] {
    let nodes = node.children.filter { $0.bytes(metric) > 0 }.sorted {
      $0.bytes(metric) == $1.bytes(metric) ? $0.id < $1.id : $0.bytes(metric) > $1.bytes(metric)
    }
    var result: [Item] = nodes.prefix(23).map { Item(node: $0, title: $0.url.lastPathComponent, bytes: $0.bytes(metric)) }
    let remainder: UInt64 = nodes.dropFirst(23).reduce(UInt64(0)) { $0 + $1.bytes(metric) }
    if remainder > 0 { result.append(Item(node: nil, title: String(localized: "其余项目"), bytes: remainder)) }
    return result
  }

  var body: some View {
    let entries = self.entries
    let weights: [Double] = entries.map { Double($0.bytes) }
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        ForEach(DiskUsageTreemapLayout.tiles(weights: weights, in: CGRect(origin: .zero, size: geometry.size)), id: \.index) { tile in
          tileView(entries[tile.index], tile: tile)
        }
      }
    }
    .frame(height: 230)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("空间占用区块图")
  }

  private func tileView(_ item: Item, tile: DiskUsageTreemapLayout.Tile) -> some View {
    DiskUsageTreemapTile(title: item.title, bytes: item.bytes, index: tile.index, size: tile.frame.size) {
      activate(item.node)
    }
    .disabled(item.node == nil)
    .help((item.node?.url.path ?? item.title) + " · " + SystemMetricFormat.bytes(item.bytes))
    .accessibilityLabel(item.title + " · " + SystemMetricFormat.bytes(item.bytes))
    .frame(width: max(0, tile.frame.width - 3), height: max(0, tile.frame.height - 3))
    .offset(x: tile.frame.minX, y: tile.frame.minY)
  }

  private func activate(_ node: DiskUsageNode?) {
    guard let node else { return }
    select(node)
  }
}

private struct DiskUsageTreemapTile: View {
  let title: String
  let bytes: UInt64
  let index: Int
  let size: CGSize
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        if size.width > 64 && size.height > 34 {
          Text(title).font(.caption.weight(.medium)).lineLimit(2).truncationMode(.middle)
          if size.height > 62 { Text(SystemMetricFormat.bytes(bytes)).font(.caption2).lineLimit(1) }
        }
      }
      .padding(size.width > 64 ? CGFloat(8) : 0)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background {
        RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.12 + Double(index % 5) * 0.06))
      }
      .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.12)) }
      .contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}
