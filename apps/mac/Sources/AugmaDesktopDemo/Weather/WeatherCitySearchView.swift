import SwiftUI

struct WeatherCitySearchView: View {
  @ObservedObject var store: WeatherStore
  @Binding var query: String
  let select: (WeatherCity) -> Void
  @State private var searchTask: Task<Void, Never>?
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      Text("添加城市").font(.headline)
      HStack(alignment: .firstTextBaseline, spacing: NativePageLayout.itemSpacing) {
        TextField("城市名称，如上海或 Tokyo", text: $query)
          .textFieldStyle(.roundedBorder)
          .focused($isSearchFocused)
          .onSubmit(search)
          .accessibilityLabel("搜索城市")
        Button("搜索", systemImage: "magnifyingglass", action: search)
          .labelStyle(.iconOnly)
          .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || store.isSearching)
        if store.isSearching { ProgressView().controlSize(.small) }
      }
      if let message = store.searchErrorMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
      if !store.searchResults.isEmpty {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(store.searchResults) { city in
              Button {
                searchTask?.cancel()
                select(city)
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(city.name).fontWeight(.medium)
                    if !city.regionDescription.isEmpty { Text(city.regionDescription).font(.caption).foregroundStyle(.secondary) }
                  }
                  Spacer()
                  Image(systemName: store.savedCities.contains(where: { $0.id == city.id }) ? "checkmark.circle" : "plus.circle")
                    .foregroundStyle(Color.augmaCyan)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              if city.id != store.searchResults.last?.id { Divider() }
            }
          }
        }
        .frame(height: min(CGFloat(store.searchResults.count) * 57, 300))
      } else if store.hasSearched {
        Text("没有找到城市，请尝试其他名称。").font(.callout).foregroundStyle(.secondary)
      }
    }
    .padding(NativePageLayout.cardPadding)
    .frame(width: 360)
    .controlSize(.regular)
    .task { isSearchFocused = true }
    .onDisappear { searchTask?.cancel() }
  }

  private func search() {
    searchTask?.cancel()
    searchTask = Task { await store.search(query: query) }
  }
}
