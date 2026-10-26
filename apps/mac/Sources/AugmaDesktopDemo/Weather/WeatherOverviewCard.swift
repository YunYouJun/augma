import SwiftUI

struct WeatherOverviewCard: View {
  let city: WeatherCity
  let snapshot: WeatherSnapshot?
  let isLoading: Bool
  let errorMessage: String?
  let notice: String?
  let refresh: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 7) {
            Text(city.name).font(.system(.title2, design: .rounded).weight(.semibold))
            if city.isCurrentLocation {
              Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(Color.augmaCyan)
                .accessibilityLabel("当前位置")
                .help("当前位置")
            }
          }
          if !city.regionDescription.isEmpty {
            Text(city.regionDescription).font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 8)
        HStack(spacing: 10) {
          if let snapshot { WeatherUpdateStatus(snapshot: snapshot) }
          if isLoading {
            ProgressView().controlSize(.small).frame(width: 22, height: 22)
          } else {
            Button("刷新天气", systemImage: "arrow.clockwise", action: refresh)
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
              .foregroundStyle(.secondary)
              .help("刷新天气")
              .frame(width: 22, height: 22)
          }
        }
        .padding(.top, 3)
      }
      if let snapshot {
        WeatherCurrentReadings(snapshot: snapshot)
      } else if !isLoading {
        ContentUnavailableView("尚无天气数据", systemImage: "cloud", description: Text("请刷新天气以获取所选城市的最新数据。"))
          .frame(maxWidth: .infinity)
      }
      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
      }
      if let notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
    }
    .padding(22)
    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 20))
    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.06)) }
  }
}

private struct WeatherUpdateStatus: View {
  let snapshot: WeatherSnapshot

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      VStack(alignment: .trailing, spacing: 3) {
        Text("更新于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
        if snapshot.isStale(at: context.date) {
          Label("数据已过期", systemImage: "clock.badge.exclamationmark")
            .help("天气数据已过期，显示上次读数")
        }
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
      .help(timestamps)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(timestamps)
      .accessibilityValue(snapshot.isStale(at: context.date) ? String(localized: "天气数据已过期，显示上次读数") : "")
    }
  }

  private var timestamps: Text {
    Text("天气时间：\(snapshot.observedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: snapshot.timeZone)))")
      + Text("\n")
      + Text("获取时间：\(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
  }
}
