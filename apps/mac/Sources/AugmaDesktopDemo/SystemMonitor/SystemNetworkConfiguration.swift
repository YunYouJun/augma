import Foundation
import SystemConfiguration

enum SystemNetworkInterfaceKind: Sendable {
  case wifi, ethernet, unknown

  var label: String? {
    switch self {
    case .wifi: "Wi-Fi"
    case .ethernet: String(localized: "以太网")
    case .unknown: nil
    }
  }
}

/// One dynamic-store snapshot keeps interface selection and its display name consistent.
struct SystemNetworkConfiguration {
  let values: [String: [String: Any]]

  static func read() -> Self {
    guard let store = SCDynamicStoreCreate(nil, "AugmaSystemMonitor" as CFString, nil, nil) else {
      return Self(values: [:])
    }
    let keys = ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6", "Setup:/Network/Global/IPv4"]
    let patterns = [
      "State:/Network/Service/.*/IPv[46]", "Setup:/Network/Service/.*/Interface",
      "State:/Network/Interface/.*/Link",
    ]
    let values = SCDynamicStoreCopyMultiple(store, keys as CFArray, patterns as CFArray) as? [String: [String: Any]]
    return Self(values: values ?? [:])
  }

  func select(_ candidates: [SystemNetworkCounters], previous: String?) -> SystemNetworkCounters? {
    let connected = candidates.filter {
      SystemMetricMath.isPhysicalInterface($0.interface)
        && values["State:/Network/Interface/\($0.interface)/Link"]?["Active"] as? Bool != false
    }
    let available = Set(connected.map(\.interface))
    let primary = preferredInterfaces.first { available.contains($0) }
    guard var selected = SystemMetricMath.selectNetworkInterface(connected, primary: primary, previous: previous) else {
      return nil
    }
    selected.kind = kind(of: selected.interface)
    return selected
  }

  private var preferredInterfaces: [String] {
    var interfaces = ["IPv4", "IPv6"].compactMap {
      values["State:/Network/Global/\($0)"]?["PrimaryInterface"] as? String
    }
    // A VPN can replace the global default with utun. Resolve the physical service
    // from current IP state in the user's service order, ahead of the old selection.
    // Setup alone is insufficient: disconnected services remain configured there.
    let statePrefix = "State:/Network/Service/"
    let serviceIDs = Set(values.keys.compactMap { key -> String? in
      guard key.hasPrefix(statePrefix), key.hasSuffix("/IPv4") || key.hasSuffix("/IPv6") else { return nil }
      return key.dropFirst(statePrefix.count).split(separator: "/").first.map(String.init)
    })
    let order = values["Setup:/Network/Global/IPv4"]?["ServiceOrder"] as? [String] ?? []
    let orderedIDs = order + serviceIDs.subtracting(order).sorted()
    var localInterfaces: [String] = []
    for serviceID in orderedIDs {
      for family in ["IPv4", "IPv6"] {
        guard let state = values["\(statePrefix)\(serviceID)/\(family)"],
          let interface = state["InterfaceName"] as? String
        else { continue }
        // Prefer services with a router over a connected, local-only adapter.
        if let router = state["Router"] as? String, !router.isEmpty { interfaces.append(interface) }
        else { localInterfaces.append(interface) }
      }
    }
    return (interfaces + localInterfaces).filter(SystemMetricMath.isPhysicalInterface)
  }

  private func kind(of interface: String) -> SystemNetworkInterfaceKind {
    for (key, value) in values where key.hasPrefix("Setup:/Network/Service/") && key.hasSuffix("/Interface") {
      guard value["DeviceName"] as? String == interface else { continue }
      // Wi-Fi reports Type=Ethernet too; Hardware distinguishes it from wired adapters.
      if value["Hardware"] as? String == "AirPort" { return .wifi }
      if value["Hardware"] as? String == "Ethernet" { return .ethernet }
    }
    return .unknown
  }
}
