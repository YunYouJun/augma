import SwiftUI

struct NativeLiveWeatherView: View {
  @ObservedObject var store: WeatherStore
  @State private var showingCitySearch = false
  @State private var query = ""
  @State private var actionTask: Task<Void, Never>?

  var body: some View {
    NativePage {
      if let city = store.selectedCity {
        WeatherOverviewCard(city: city, snapshot: store.snapshot, isLoading: store.isLoading,
                            errorMessage: store.errorMessage, notice: store.notice) {
          perform { await store.refresh() }
        }
      } else {
        emptyState
      }
      if let message = store.locationErrorMessage {
        Label(message, systemImage: "location.slash")
          .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
      }
      if !store.savedCities.isEmpty { cities }
      WeatherAttributionView()
    }
    .task { await store.loadIfNeeded() }
    .onDisappear { actionTask?.cancel() }
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      Image(systemName: "cloud.sun")
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 48, weight: .light))
        .accessibilityHidden(true)
      Text("选择天气城市").font(.title2.bold())
      Text("使用当前位置查看天气，或搜索并添加多个城市。")
        .foregroundStyle(.secondary)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: NativePageLayout.itemSpacing) { emptyActions }.fixedSize()
        VStack(spacing: NativePageLayout.itemSpacing) { emptyActions }
      }
      .controlSize(.large)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .nativeCard()
  }

  @ViewBuilder private var emptyActions: some View {
    locationButton.buttonStyle(.borderedProminent)
    addCityButton
  }

  private var cities: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: NativePageLayout.itemSpacing) {
          Text("我的城市").font(.headline).fixedSize()
          Spacer(minLength: 8)
          HStack(spacing: NativePageLayout.itemSpacing) { cityActions }.fixedSize()
        }
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
          Text("我的城市").font(.headline)
          ViewThatFits(in: .horizontal) {
            HStack(spacing: NativePageLayout.itemSpacing) { cityActions }.fixedSize()
            VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { cityActions }
          }
        }
      }
      if store.savedCities.count <= 4 {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { cityCards }
          cityGrid
        }
      } else {
        cityGrid
      }
    }
  }

  @ViewBuilder private var cityActions: some View {
    locationButton
    addCityButton
  }

  private var cityGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: NativePageLayout.itemSpacing)], spacing: NativePageLayout.itemSpacing) { cityCards }
  }

  private var cityCards: some View {
    ForEach(store.savedCities) { city in
      WeatherCityCard(city: city, snapshot: store.cachedWeather(for: city), isSelected: store.selectedCity?.id == city.id) {
        perform { await store.selectCity(city) }
      } remove: {
        perform { await store.removeCity(city) }
      }
      .frame(minWidth: 175)
    }
  }

  private var addCityButton: some View {
    Button("添加城市", systemImage: "plus") { showingCitySearch = true }
      .popover(isPresented: $showingCitySearch, arrowEdge: .bottom) {
        WeatherCitySearchView(store: store, query: $query) { city in
          showingCitySearch = false
          query = ""
          perform { await store.selectCity(city) }
        }
      }
  }

  private var locationButton: some View {
    Button {
      perform { await store.useCurrentLocation() }
    } label: {
      HStack(spacing: 6) {
        if store.isLocating { ProgressView().controlSize(.small) }
        Label(store.isLocating ? String(localized: "正在定位…") : String(localized: "使用当前位置"), systemImage: "location")
      }
    }
    .disabled(store.isLocating)
  }

  private func perform(_ action: @escaping @MainActor () async -> Void) {
    actionTask?.cancel()
    actionTask = Task { await action() }
  }
}

private struct WeatherAttributionView: View {
  @State private var showingDetails = false

  var body: some View {
    HStack(spacing: 6) {
      Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
      Text("·")
      Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
      Spacer()
      Button("数据来源", systemImage: "info.circle") { showingDetails.toggle() }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("数据来源")
        .popover(isPresented: $showingDetails) {
          VStack(alignment: .leading, spacing: 12) {
            Text("数据来源").font(.headline)
            Link("城市数据：GeoNames", destination: URL(string: "https://www.geonames.org/")!)
            Text("天气来自气象模型的当前估计；缓存 15 分钟，手动刷新间隔至少 1 分钟。")
            Text("点击“使用当前位置”时才申请定位权限，仅获取一次大致位置。城市和天气缓存保存在本机。")
            Text("向 Open-Meteo 发送搜索词和城市坐标；定位时由 Apple 解析城市名称。免费天气接口仅限非商业使用。")
            Link("Open-Meteo 使用条款", destination: URL(string: "https://open-meteo.com/en/terms")!)
          }
          .font(.callout)
          .padding(20)
          .frame(width: 340, alignment: .leading)
        }
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 4)
  }
}
