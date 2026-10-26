import AppKit
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

final class SystemCapacityStyleTests: XCTestCase {
  func testCapacityFractionsDistinguishZeroFromUnavailableAndClampInconsistentReads() {
    XCTAssertEqual(SystemCapacityStyle.fraction(used: 0, total: 100), 0)
    XCTAssertNil(SystemCapacityStyle.fraction(used: 0, total: 0))
    XCTAssertEqual(SystemCapacityStyle.fraction(used: 150, total: 100), 1)
    XCTAssertEqual(SystemCapacityStyle.fraction(used: .max, total: .max), 1)
    XCTAssertEqual(SystemCapacityStyle.fraction(0.8), 0.8)
    XCTAssertEqual(SystemCapacityStyle.fraction(-1), 0)
    XCTAssertEqual(SystemCapacityStyle.fraction(2), 1)
    for invalid in [Double.nan, .infinity, -.infinity] { XCTAssertNil(SystemCapacityStyle.fraction(invalid)) }
    XCTAssertNil(SystemCapacityStyle.fraction(nil))
  }

  func testDiskStatusUsesRemainingSpaceAndWarnsAtTheDocumentedBoundaries() {
    func disk(_ available: UInt64, total: UInt64 = 100) -> DiskUsage {
      DiskUsage(id: "disk", name: "Volume", total: total, available: available)
    }
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(18)), .normal, "82% used is not a warning")
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(11)), .normal)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(10)), .warning)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(6)), .warning)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(5)), .critical)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(0)), .critical)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(120)), .normal)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(disk(0, total: 0)), .unavailable)
    XCTAssertEqual(SystemCapacityStyle.diskSeverity(nil), .unavailable)
  }

  func testBatteryStatusDistinguishesLowBatteryFromExternalPowerAndUnavailableData() {
    func battery(_ level: Double, plugged: Bool = false) -> BatteryStatus {
      BatteryStatus(level: level, isCharging: plugged, isPluggedIn: plugged, minutesRemaining: nil)
    }
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(battery(0.99)), .normal)
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(battery(0.21)), .normal)
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(battery(0.20)), .warning)
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(battery(0.10)), .critical)
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(battery(0.05, plugged: true)), .normal)
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(battery(.nan)), .unavailable)
    XCTAssertEqual(SystemCapacityStyle.batterySeverity(nil), .unavailable)
  }

  @MainActor func testNativeCapacityViewsFitTheMenuAndTheExistingHUD() async throws {
    let domain = "augma-capacity-layout-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = SystemMonitorStore(reader: CapacityPreviewSampler(), defaults: defaults, observeLifecycle: false)
    await store.refresh()
    for dark in [false, true] {
      let menu = ImageRenderer(content: SystemMonitorSummary(store: store).frame(width: 368).padding(16)
        .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light))
      menu.scale = 2
      let image = try XCTUnwrap(menu.nsImage)
      XCTAssertEqual(image.size.width, 400, accuracy: 1)
      XCTAssertLessThan(image.size.height, 160, "The four rings must remain a compact menu summary")
      if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CAPACITY_DIR"] {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(filePath: directory).appendingPathComponent(dark ? "menu-dark.png" : "menu-light.png"))
      }
    }
    let hud = ImageRenderer(content: SystemMonitorHUD(store: store).frame(width: 390))
    let hudImage = try XCTUnwrap(hud.nsImage)
    XCTAssertLessThanOrEqual(hudImage.size.height, 162, "The HUD must fit without clipping its network values")
  }

  @MainActor func testDashboardUsesTwoColumnsOnWideViewsAndStacksOnNarrowViews() async throws {
    let snapshot = await CapacityPreviewSampler().sample(options: SystemSamplingOptions(includeDisks: true))
    var heights: [Int: CGFloat] = [:]
    for width in [320, 480, 768, 1040] {
      for dark in [false, true] {
        // Native GroupBox uses AppKit views, which ImageRenderer omits. Render an
        // off-screen native host so an image of headings alone cannot pass this check.
        let content = SystemMonitorDashboard(snapshot: snapshot,
          columns: SystemMonitorDashboardLayout.columnCount(for: CGFloat(width)))
          .frame(width: CGFloat(width)).padding(16)
          .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: width + 32, height: 1_200)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        host.frame.size = size
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        XCTAssertEqual(size.width, CGFloat(width + 32), accuracy: 1)
        XCTAssertGreaterThan(size.height, width >= 656 ? 280 : 500,
                             "All four metric bodies must be visible, not just their native headings")
        heights[width] = size.height
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CAPACITY_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
          let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          try data.write(to: URL(filePath: directory).appendingPathComponent("dashboard-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
    XCTAssertLessThan(try XCTUnwrap(heights[768]), try XCTUnwrap(heights[480]) * 0.7,
                      "Wide windows must use horizontal space and substantially reduce scrolling")
  }
}

private actor CapacityPreviewSampler: SystemMetricsSampling {
  func resetBaseline() {}
  func suspend() {}
  func sample(options: SystemSamplingOptions) -> SystemSnapshot {
    SystemSnapshot(cpu: CPUUsage(user: 0.18, system: 0.10),
                   memory: MemoryUsage(total: 48 << 30, used: 37 << 30, compressed: 12 << 30, swapUsed: 4 << 30, pressure: .normal),
                   disks: [DiskUsage(id: "disk", name: "Macintosh HD", total: 995_000_000_000, available: 176_000_000_000)],
                   network: NetworkUsage(interface: "en0", receivedPerSecond: 43_000, sentPerSecond: 58_000),
                   battery: BatteryStatus(level: 0.99, isCharging: true, isPluggedIn: true, minutesRemaining: nil))
  }
}
