import SwiftUI

struct NativeLiveWeatherView: View {
  @ObservedObject var store: WeatherStore
  @State private var query = ""
  @State private var searchTask: Task<Void, Never>?
  @State private var actionTask: Task<Void, Never>?

  var body: some View {
    Form {
      if let city = store.selectedCity {
        Section {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(city.name).font(.title2.bold())
              if !city.regionDescription.isEmpty { Text(city.regionDescription).foregroundStyle(.secondary) }
            }
            Spacer()
            if store.isLoading { ProgressView().controlSize(.small) }
            Button("刷新天气", systemImage: "arrow.clockwise") {
              actionTask?.cancel()
              actionTask = Task { await store.refresh() }
            }
            .disabled(store.isLoading)
          }
          if let snapshot = store.snapshot {
            WeatherCurrentReadings(snapshot: snapshot)
            TimelineView(.periodic(from: .now, by: 60)) { context in
              VStack(alignment: .leading, spacing: 4) {
                if snapshot.isStale(at: context.date) {
                  Label("天气数据已过期，显示上次读数", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                }
                Text("天气时间：\(snapshot.observedAt.formatted(dateFormat(snapshot)))")
                Text("获取时间：\(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          } else if !store.isLoading {
            ContentUnavailableView("尚无天气数据", systemImage: "cloud", description: Text("请刷新天气以获取所选城市的最新数据。"))
          }
          if let error = store.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
          if let notice = store.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
        } header: { Text("当前天气") }
      } else {
        Section {
          ContentUnavailableView("选择天气城市", systemImage: "cloud.sun", description: Text("搜索并选择城市后显示天气。不会自动获取设备位置。"))
        }
      }

      Section {
        HStack {
          TextField("城市名称，如上海或 Tokyo", text: $query)
            .onSubmit(search)
            .accessibilityLabel("搜索城市")
          Button("搜索", systemImage: "magnifyingglass", action: search)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || store.isSearching)
          if store.isSearching { ProgressView().controlSize(.small) }
        }
        if let message = store.searchErrorMessage { Text(message).foregroundStyle(.secondary) }
        ForEach(store.searchResults) { city in cityButton(city) }
        if store.hasSearched && store.searchResults.isEmpty { Text("没有找到城市，请尝试其他名称。").foregroundStyle(.secondary) }
      } header: { Text("切换城市") }

      if !store.recentCities.isEmpty {
        Section {
          ForEach(store.recentCities) { city in cityButton(city) }
        } header: { Text("最近选择") }
      }

      Section {
        HStack {
          Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
          Text("·").foregroundStyle(.secondary)
          Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
        }
        .font(.caption)
        Link("城市数据：GeoNames", destination: URL(string: "https://www.geonames.org/")!)
          .font(.caption)
        Text("天气来自气象模型的当前估计；缓存 15 分钟，手动刷新间隔至少 1 分钟。")
        Text("仅向 Open-Meteo 发送搜索词和所选城市坐标，无需定位权限。免费接口仅限非商业使用。")
        Link("Open-Meteo 使用条款", destination: URL(string: "https://open-meteo.com/en/terms")!)
          .font(.caption)
      } header: { Text("数据来源") }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .task { await store.loadIfNeeded() }
    .onDisappear {
      searchTask?.cancel()
      actionTask?.cancel()
    }
  }

  private func cityButton(_ city: WeatherCity) -> some View {
    Button {
      searchTask?.cancel()
      actionTask?.cancel()
      actionTask = Task { await store.selectCity(city) }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(city.name)
          if !city.regionDescription.isEmpty { Text(city.regionDescription).font(.caption).foregroundStyle(.secondary) }
        }
        Spacer()
        if store.selectedCity?.id == city.id { Image(systemName: "checkmark").accessibilityLabel("当前城市") }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.vertical, 3)
  }

  private func search() {
    searchTask?.cancel()
    searchTask = Task { await store.search(query: query) }
  }

  private func dateFormat(_ snapshot: WeatherSnapshot) -> Date.FormatStyle {
    Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: snapshot.timeZone)
  }
}

private struct WeatherCurrentReadings: View {
  let snapshot: WeatherSnapshot

  var body: some View {
    HStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(systemName: snapshot.condition.symbol)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 48))
          .accessibilityHidden(true)
        Text(snapshot.temperature.formatted(.number.precision(.fractionLength(0))) + " °C")
          .font(.system(size: 48, weight: .light, design: .rounded))
          .monospacedDigit()
        Text(snapshot.condition.description).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      VStack(spacing: 12) {
        LabeledContent("体感温度", value: snapshot.apparentTemperature.formatted(.number.precision(.fractionLength(0))) + " °C")
        LabeledContent("相对湿度", value: snapshot.relativeHumidity.formatted(.number.precision(.fractionLength(0))) + " %")
        LabeledContent("风速", value: snapshot.windSpeed.formatted(.number.precision(.fractionLength(1))) + " km/h")
        if let high = snapshot.highTemperature { LabeledContent("今日最高", value: high.formatted(.number.precision(.fractionLength(0))) + " °C") }
        if let low = snapshot.lowTemperature { LabeledContent("今日最低", value: low.formatted(.number.precision(.fractionLength(0))) + " °C") }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
  }
}
