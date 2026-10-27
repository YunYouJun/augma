import SwiftUI

/// Presentation stays readable even when the adjacent selection control is disabled.
struct SimulatorCleanupItemLabel: View {
  let item: SimulatorCleanupItem

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      SimulatorCleanupIcon(item: item)
        .frame(width: 36, height: 40)
        .background(itemColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(item.name).font(.callout.weight(.medium)).foregroundStyle(.primary)
            .lineLimit(2).truncationMode(.middle).help(item.name)
          Spacer(minLength: 4)
          Text(item.bytes.map { SystemMetricFormat.bytes($0, style: .file) } ?? String(localized: "大小未知"))
            .font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
            .fixedSize(horizontal: true, vertical: false)
        }

        HStack(spacing: 8) {
          if item.kind == .device { Text(systemTitle).font(.caption).foregroundStyle(.secondary) }
          Label {
            Text(stateTitle)
          } icon: {
            Image(systemName: stateSymbol).accessibilityHidden(true)
          }
          .font(.caption2.weight(.medium)).foregroundStyle(stateColor)
          .padding(.horizontal, 7).padding(.vertical, 3)
          .background(stateColor.opacity(0.10), in: Capsule())
        }

        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) { lastUsed; dependencies }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: 4) { lastUsed; dependencies }
        }
        .font(.caption).foregroundStyle(.secondary)

        if let restriction = item.restriction {
          Label {
            Text(restriction).fixedSize(horizontal: false, vertical: true)
          } icon: {
            Image(systemName: "lock.shield").accessibilityHidden(true)
          }
          .font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text((item.kind == .device ? String(localized: "模拟器设备") : String(localized: "共享运行时"))
                             + ": " + item.name))
    .accessibilityValue(Text(accessibilityDetails))
  }

  private var accessibilityDetails: String {
    var details = [item.bytes.map { SystemMetricFormat.bytes($0, style: .file) } ?? String(localized: "大小未知"),
                   systemTitle, stateTitle]
    if let date = item.lastUsedAt {
      details.append(String(format: String(localized: "最后使用：%@"),
                            date.formatted(.dateTime.year().month().day().hour().minute())))
    } else {
      details.append(String(localized: "最后使用时间未知"))
    }
    if item.kind == .runtime {
      details.append(String(format: String(localized: "默认设备集关联 %lld 台"), item.dependentDeviceCount))
    }
    if let restriction = item.restriction { details.append(restriction) }
    return details.joined(separator: ", ")
  }

  @ViewBuilder private var lastUsed: some View {
    if let date = item.lastUsedAt {
      let displayDate = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        ? date.formatted(.dateTime.month().day().hour().minute())
        : date.formatted(.dateTime.year().month().day().hour().minute())
      Label {
        Text(String(format: String(localized: "最后使用：%@"), displayDate))
      } icon: {
        Image(systemName: "clock").accessibilityHidden(true)
      }
      .help(date.formatted(.dateTime.year().month().day().hour().minute()))
    } else {
      Label("最后使用时间未知", systemImage: "clock")
    }
  }

  @ViewBuilder private var dependencies: some View {
    if item.kind == .runtime {
      Label {
        Text(String(format: String(localized: "默认设备集关联 %lld 台"), item.dependentDeviceCount))
      } icon: {
        Image(systemName: "link").accessibilityHidden(true)
      }
    }
  }

  private var itemColor: Color { item.kind == .device ? .augmaCyan : .augmaAccent }

  private var systemTitle: String {
    let platform = item.runtimeIdentifier.split(separator: ".").last?.split(separator: "-").first.map(String.init) ?? "iOS"
    return platform + " " + (item.version ?? "—")
  }

  private var stateTitle: String {
    if item.isAvailable == false { return String(localized: "不可用") }
    if item.kind == .device {
      if item.state == "Booted" { return String(localized: "运行中") }
      if item.state == "Shutdown" { return String(localized: "已关闭") }
    } else if item.state == "Ready" { return String(localized: "已安装") }
    return String(localized: "状态未知")
  }

  private var stateSymbol: String {
    if item.isAvailable == false { return "exclamationmark.circle" }
    if item.kind == .device {
      if item.state == "Booted" { return "play.circle.fill" }
      if item.state == "Shutdown" { return "power" }
    } else if item.state == "Ready" { return "checkmark.circle" }
    return "questionmark.circle"
  }

  private var stateColor: Color {
    if item.isAvailable == false { return .augmaAccent }
    if item.kind == .device {
      if item.state == "Booted" { return .augmaHealthy }
      if item.state == "Shutdown" { return .secondary }
    } else if item.state == "Ready" { return .augmaCyan }
    return .augmaAccent
  }
}
