import MapKit
import SwiftUI

struct NativeMapView: View {
  @ObservedObject var store: NativeMapStore

  var body: some View {
    Form {
      Section {
        Map(position: $store.cameraPosition) {
          if let origin = store.origin {
            Marker(String(localized: "起点") + " · " + origin.name, systemImage: "circle.fill", coordinate: origin.coordinate.location)
              .tint(.green)
          }
          if let destination = store.destination {
            Marker(String(localized: "终点") + " · " + destination.name, systemImage: "mappin", coordinate: destination.coordinate.location)
              .tint(.red)
          }
          if let route = store.route {
            MapPolyline(coordinates: route.coordinates.map(\.location))
              .stroke(.blue, lineWidth: 5)
          }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { MapCompass(); MapScaleView() }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("路线地图")
        Text("搜索真实地点并选择起终点，不会自动获取当前位置。")
          .font(.caption).foregroundStyle(.secondary)
      } header: { Text("地图与路线") }

      NativeMapEndpointSearchView(store: store, endpoint: .origin)
      NativeMapEndpointSearchView(store: store, endpoint: .destination)

      Section {
        Picker("出行方式", selection: $store.transport) {
          ForEach(NativeMapTransport.allCases) { transport in Text(transport.title).tag(transport) }
        }
        .pickerStyle(.segmented)
        HStack {
          Button("规划路线", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            Task { await store.calculateRoute() }
          }
          .disabled(!store.canRoute || store.isRouting)
          if store.isRouting { ProgressView().controlSize(.small) }
          Spacer()
          if store.route != nil {
            Button("清除路线", systemImage: "xmark") { store.clearRoute() }
          }
        }
        if let route = store.route {
          HStack {
            Label(route.distanceText, systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
            Spacer()
            Label(route.durationText, systemImage: "clock")
          }
          .font(.headline)
          if !route.name.isEmpty { Text(route.name).foregroundStyle(.secondary) }
          if !route.steps.isEmpty {
            Button {
              store.showsSteps.toggle()
            } label: {
              Label(store.showsSteps ? String(localized: "收起分步路线") : String(localized: "显示分步路线"),
                    systemImage: store.showsSteps ? "chevron.up" : "chevron.down")
            }
            .accessibilityIdentifier("native-map-toggle-steps")
            if store.showsSteps {
              ForEach(route.steps.indices, id: \.self) { index in
                let step = route.steps[index]
                HStack(alignment: .top, spacing: 10) {
                  Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(step.instruction)
                    if step.distance > 0 { Text(NativeMapRoute.distanceText(step.distance)).font(.caption).foregroundStyle(.secondary) }
                  }
                  Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
              }
            }
          }
        }
        if let error = store.routeError { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
        Button("在苹果地图中打开", systemImage: "arrow.up.forward.app") {
          Task { await store.openInAppleMaps() }
        }
        .disabled(!store.canRoute || store.isOpeningMaps)
        if let notice = store.mapsNotice { Text(notice).font(.caption).foregroundStyle(.secondary) }
        Text("Augma 显示路线规划与分步指引；在苹果地图中打开可使用系统地图功能。路线与预计时间来自 Apple，可能随路况变化。")
          .font(.caption).foregroundStyle(.secondary)
      } header: { Text("路线规划") }
    }
    .formStyle(.grouped)
  }
}

private struct NativeMapEndpointSearchView: View {
  @ObservedObject var store: NativeMapStore
  let endpoint: NativeMapEndpoint

  var body: some View {
    Section {
      HStack {
        TextField(String(localized: "搜索地点或地址"), text: Binding(
          get: { store.query(for: endpoint) },
          set: { if endpoint == .origin { store.originQuery = $0 } else { store.destinationQuery = $0 } }
        ))
        .onSubmit(search)
        .accessibilityLabel(endpoint.title + String(localized: "地点搜索"))
        Button("搜索", systemImage: "magnifyingglass", action: search)
          .disabled(store.searching.contains(endpoint) || store.query(for: endpoint).trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
        if store.searching.contains(endpoint) { ProgressView().controlSize(.small) }
      }
      if let selected = store.selected(for: endpoint) {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text(selected.name)
            if !selected.address.isEmpty { Text(selected.address).font(.caption).foregroundStyle(.secondary) }
          }
        } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
      }
      ForEach(store.results(for: endpoint)) { place in
        Button {
          store.select(place, for: endpoint)
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(place.name)
              if !place.address.isEmpty { Text(place.address).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            Image(systemName: "plus.circle").foregroundStyle(.secondary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
      }
      if let error = store.searchErrors[endpoint] { Text(error).foregroundStyle(.secondary) }
      if store.searched.contains(endpoint) && store.results(for: endpoint).isEmpty {
        Text("没有找到地点，请尝试更完整的名称或地址。").foregroundStyle(.secondary)
      }
    } header: { Text(endpoint.title) }
  }

  private func search() { Task { await store.search(endpoint) } }
}
