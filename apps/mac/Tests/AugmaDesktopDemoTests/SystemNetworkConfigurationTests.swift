import XCTest
@testable import AugmaDesktopDemo

final class SystemNetworkConfigurationTests: XCTestCase {
  private let wifi = SystemNetworkCounters(interface: "en0", received: 900_000_000, sent: 500_000_000)
  private let ethernet = SystemNetworkCounters(interface: "en5", received: 1_000, sent: 500)
  private let vpn = SystemNetworkCounters(interface: "utun4", received: 1_000_000_000, sent: 1_000_000_000)

  func testVPNUsesConnectedServiceOrderInsteadOfPreviousInterfaceOrBootTotals() {
    let configuration = configuration(primary: "utun4", order: ["wired", "wifi"])
    let selected = configuration.select([wifi, ethernet, vpn], previous: "en0")
    XCTAssertEqual(selected?.interface, "en5")
    XCTAssertEqual(selected?.received, ethernet.received, "VPN counters must not be added")
    XCTAssertEqual(selected?.kind, .ethernet)

    let reordered = self.configuration(primary: "utun4", order: ["wifi", "wired"])
    XCTAssertEqual(reordered.select([ethernet, wifi, vpn], previous: "en5")?.interface, "en0")
  }

  func testPhysicalDefaultTakesPriorityOverServiceOrderAndPreviousSelection() {
    let configuration = configuration(primary: "en0", order: ["wired", "wifi"])
    XCTAssertEqual(configuration.select([wifi, ethernet, vpn], previous: "en5")?.interface, "en0")
  }

  func testIPv6PhysicalDefaultIsUsedWhenIPv4DefaultIsAVPN() {
    var values = configuration(primary: "utun4", order: ["wired", "wifi"]).values
    values["State:/Network/Global/IPv6"] = ["PrimaryInterface": "en0"]
    values["State:/Network/Service/wifi/IPv4"] = nil
    values["State:/Network/Service/wifi/IPv6"] = ["InterfaceName": "en0", "Router": "fe80::1"]
    XCTAssertEqual(SystemNetworkConfiguration(values: values).select([wifi, ethernet, vpn], previous: "en5")?.interface, "en0")
  }

  func testDisconnectedLinkCannotRemainSelectedEvenWithStaleDefaultAndIPState() {
    var values = configuration(primary: "en5", order: ["wired", "wifi"]).values
    values["State:/Network/Interface/en5/Link"] = ["Active": false]
    XCTAssertEqual(SystemNetworkConfiguration(values: values).select([wifi, ethernet, vpn], previous: "en5")?.interface, "en0")
    values["State:/Network/Interface/en0/Link"] = ["Active": false]
    XCTAssertNil(SystemNetworkConfiguration(values: values).select([wifi, ethernet, vpn], previous: "en5"))
  }

  func testConfiguredServiceWithoutCurrentIPStateDoesNotKeepTheOldSelection() {
    var values = configuration(primary: "utun4", order: ["wired", "wifi"]).values
    values["State:/Network/Service/wired/IPv4"] = nil
    XCTAssertEqual(SystemNetworkConfiguration(values: values).select([wifi, ethernet, vpn], previous: "en5")?.interface, "en0")
  }

  func testRoutedServiceIsPreferredOverLocalOnlyAdapterBehindVPN() {
    var values = configuration(primary: "utun4", order: ["wired", "wifi"]).values
    values["State:/Network/Service/wired/IPv4"] = ["InterfaceName": "en5"]
    XCTAssertEqual(SystemNetworkConfiguration(values: values).select([wifi, ethernet, vpn], previous: "en5")?.interface, "en0")
  }

  func testActiveServiceCanBeDiscoveredWithoutConfiguredServiceOrder() {
    var values = configuration(primary: "utun4", order: []).values
    values["State:/Network/Service/wifi/IPv4"] = nil
    XCTAssertEqual(SystemNetworkConfiguration(values: values).select([wifi, ethernet, vpn], previous: "en0")?.interface, "en5")
  }

  func testUnavailableConfigurationHasAStableFallbackAndNeverSelectsVirtualInterfaces() {
    let configuration = SystemNetworkConfiguration(values: [:])
    XCTAssertEqual(configuration.select([wifi, ethernet, vpn], previous: "en5")?.interface, "en5")
    XCTAssertEqual(configuration.select([ethernet, wifi, vpn], previous: nil)?.interface, "en0")
    XCTAssertNil(configuration.select([vpn], previous: "utun4"))
  }

  func testSwitchingFromWiFiToEthernetAndBackReestablishesTheRateBaseline() throws {
    let wifiConfiguration = configuration(primary: "en0", order: ["wired", "wifi"])
    let vpnConfiguration = configuration(primary: "utun4", order: ["wired", "wifi"])
    let before = try XCTUnwrap(wifiConfiguration.select([wifi, ethernet, vpn], previous: nil))
    let switched = try XCTUnwrap(vpnConfiguration.select([wifi, ethernet, vpn], previous: before.interface))
    XCTAssertNil(SystemMetricMath.networkUsage(previous: before, current: switched, interval: 2))
    var nextEthernet = ethernet
    nextEthernet.received += 8_000
    nextEthernet.sent += 2_000
    let next = try XCTUnwrap(vpnConfiguration.select([wifi, nextEthernet, vpn], previous: switched.interface))
    let rate = try XCTUnwrap(SystemMetricMath.networkUsage(previous: switched, current: next, interval: 2))
    XCTAssertEqual(rate.receivedPerSecond, 4_000)
    XCTAssertEqual(rate.sentPerSecond, 1_000)
    XCTAssertEqual(rate.kind, .ethernet)
    let back = try XCTUnwrap(wifiConfiguration.select([wifi, nextEthernet, vpn], previous: next.interface))
    XCTAssertNil(SystemMetricMath.networkUsage(previous: next, current: back, interval: 2))
    XCTAssertEqual(back.kind, .wifi, "AirPort hardware reports Type=Ethernet and must still be identified as Wi-Fi")
  }

  private func configuration(primary: String, order: [String]) -> SystemNetworkConfiguration {
    SystemNetworkConfiguration(values: [
      "State:/Network/Global/IPv4": ["PrimaryInterface": primary],
      "Setup:/Network/Global/IPv4": ["ServiceOrder": order],
      "Setup:/Network/Service/wifi/Interface": ["DeviceName": "en0", "Hardware": "AirPort", "Type": "Ethernet"],
      "Setup:/Network/Service/wired/Interface": ["DeviceName": "en5", "Hardware": "Ethernet", "Type": "Ethernet"],
      "State:/Network/Service/wifi/IPv4": ["InterfaceName": "en0", "Router": "192.0.2.1"],
      "State:/Network/Service/wired/IPv4": ["InterfaceName": "en5", "Router": "198.51.100.1"],
      "State:/Network/Service/vpn/IPv4": ["InterfaceName": "utun4", "Router": "203.0.113.1"],
      "State:/Network/Interface/en0/Link": ["Active": true],
      "State:/Network/Interface/en5/Link": ["Active": true],
    ])
  }
}
