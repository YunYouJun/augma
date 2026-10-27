import AppKit
import SwiftUI

struct ApplicationMemoryRanking: View {
  let snapshot: ApplicationMemorySnapshot?
  let sampling: Bool
  @State private var showingAll = false

  var body: some View {
    if let snapshot {
      if snapshot.applications.isEmpty {
        Label("暂未发现可统计的应用", systemImage: "app.dashed")
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array((showingAll ? snapshot.applications : Array(snapshot.applications.prefix(10))).enumerated()), id: \.element.id) { index, usage in
          ApplicationMemoryRow(usage: usage, rank: index + 1,
                               largestFootprint: snapshot.applications.first?.physicalFootprint ?? 0)
        }
        if snapshot.applications.count > 10 {
          Button {
            showingAll.toggle()
          } label: {
            if showingAll { Label("收起排行", systemImage: "chevron.up") }
            else {
              Label(String(format: String(localized: "查看全部 %lld 个应用"), snapshot.applications.count), systemImage: "chevron.down")
            }
          }
          .controlSize(.small)
          .nativeFloatingButton()
        }
      }
    } else {
      SystemMetricUnavailable(sampling: sampling)
    }
  }
}

struct ApplicationMemoryRow: View {
  let usage: ApplicationMemoryUsage
  let rank: Int
  var largestFootprint: UInt64 = 0
  var compact = false

  var body: some View {
    HStack(alignment: .center, spacing: compact ? 8 : 12) {
      Text(rank.formatted())
        .font(.caption.monospacedDigit())
        .fontWeight(rank == 1 ? .semibold : .regular)
        .foregroundStyle(rank == 1 ? Color.augmaCyan : .secondary)
        .frame(minWidth: compact ? 12 : 20, alignment: .trailing)
        .accessibilityHidden(true)
      AppleIconView(request: .application(bundlePath: usage.application.bundlePath), size: compact ? 22 : 32)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: compact ? 2 : 6) {
        HStack(alignment: .firstTextBaseline) {
          Text(usage.application.name)
            .lineLimit(1).truncationMode(.middle)
            .help(usage.application.name)
          Spacer(minLength: 8)
          Text(usage.measuredProcessCount > 0 ? SystemMetricFormat.bytes(usage.physicalFootprint) : "—")
            .font(compact ? .callout.monospacedDigit() : .system(.body, design: .rounded).monospacedDigit())
            .fixedSize()
        }
        if !compact {
          HStack {
            Text(String(format: String(localized: "%lld 个进程"), usage.processCount))
            if usage.unreadableProcessCount > 0 {
              Text("部分进程不可读取").foregroundStyle(Color.augmaAccent)
            }
          }
          .font(.caption).foregroundStyle(.secondary)
          if usage.measuredProcessCount > 0 {
            ProgressView(value: Double(usage.physicalFootprint), total: Double(max(1, largestFootprint)))
              .tint(.augmaCyan)
              .accessibilityLabel("相对最高应用的内存占用")
          }
        } else if usage.unreadableProcessCount > 0 {
          Text("部分进程不可读取").font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, compact ? 2 : 5)
    .accessibilityElement(children: .combine)
  }
}

struct ApplicationMemoryMenuSummary: View {
  let snapshot: ApplicationMemorySnapshot?
  let sampling: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("内存占用前三").font(.caption).foregroundStyle(.secondary)
      if let snapshot {
        if snapshot.applications.isEmpty {
          Text("暂未发现可统计的应用").font(.caption).foregroundStyle(.secondary)
        }
        ForEach(Array(snapshot.topApplications.enumerated()), id: \.element.id) { index, usage in
          ApplicationMemoryRow(usage: usage, rank: index + 1, compact: true)
        }
      } else {
        SystemMetricUnavailable(sampling: sampling).font(.caption)
      }
    }
  }
}
