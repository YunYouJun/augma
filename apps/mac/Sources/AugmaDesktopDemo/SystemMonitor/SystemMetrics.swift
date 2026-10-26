import Darwin
import DiskArbitration
import Foundation
import IOKit.ps
import SystemConfiguration

struct SystemSnapshot: Sendable {
  var sampledAt: Date = .now
  var cpu: CPUUsage? = nil
  var memory: MemoryUsage? = nil
  var applicationMemory: ApplicationMemorySnapshot? = nil
  var sensors: HardwareSensorSnapshot? = nil
  var disks: [DiskUsage] = []
  var network: NetworkUsage? = nil
  var battery: BatteryStatus? = nil
}

struct CPUUsage: Sendable {
  var user: Double
  var system: Double
  var total: Double { min(max(user + system, 0), 1) }
}

enum MemoryPressure: String, Sendable {
  case normal, warning, critical, unknown
}

struct MemoryUsage: Sendable {
  var total: UInt64
  var used: UInt64
  var compressed: UInt64
  var swapUsed: UInt64
  var pressure: MemoryPressure
}

struct DiskUsage: Identifiable, Sendable {
  var id: String
  var name: String
  var total: UInt64
  var available: UInt64
  var used: UInt64 { total - min(available, total) }
}

struct NetworkUsage: Sendable {
  var interface: String
  var receivedPerSecond: Double
  var sentPerSecond: Double
}

struct BatteryStatus: Sendable {
  var level: Double
  var isCharging: Bool
  var isPluggedIn: Bool
  var minutesRemaining: Int?
}

// These counter types keep sampling policy independent of C APIs and make resets testable.
struct SystemCPUCounters: Sendable {
  var user: UInt32
  var system: UInt32
  var idle: UInt32
  var nice: UInt32
}

struct SystemNetworkCounters: Sendable {
  var interface: String
  var received: UInt64
  var sent: UInt64
}

enum SystemMetricMath {
  // A long sampling pause establishes a new baseline, so sleep/background time is never
  // presented as a current transfer rate. The store also resets on workspace wake.
  static let maximumSampleInterval: TimeInterval = 30

  static func validInterval(_ interval: TimeInterval?) -> Bool {
    guard let interval else { return false }
    return interval.isFinite && interval > 0 && interval <= maximumSampleInterval
  }

  static func cpuUsage(previous: SystemCPUCounters?, current: SystemCPUCounters?, interval: TimeInterval?) -> CPUUsage? {
    guard validInterval(interval), let previous, let current else { return nil }
    // Mach exposes 32-bit ticks. A genuine wrap has a small modulo delta; a large
    // backwards jump is a reset or invalid read and must not look like full load.
    let deltas = [
      current.user &- previous.user,
      current.system &- previous.system,
      current.idle &- previous.idle,
      current.nice &- previous.nice,
    ]
    guard deltas.allSatisfy({ $0 < UInt32.max / 2 }) else { return nil }
    let ticks = deltas.map(Double.init)
    let total = ticks.reduce(0, +)
    guard total > 0 else { return nil }
    return CPUUsage(user: (ticks[0] + ticks[3]) / total, system: ticks[1] / total)
  }

  static func networkUsage(previous: SystemNetworkCounters?, current: SystemNetworkCounters?, interval: TimeInterval?) -> NetworkUsage? {
    guard validInterval(interval), let interval, let previous, let current,
      previous.interface == current.interface,
      current.received >= previous.received, current.sent >= previous.sent
    else { return nil }
    return NetworkUsage(
      interface: current.interface,
      receivedPerSecond: Double(current.received - previous.received) / interval,
      sentPerSecond: Double(current.sent - previous.sent) / interval
    )
  }

  static func isPhysicalInterface(_ name: String) -> Bool {
    // macOS assigns enN to built-in Wi-Fi, Ethernet and USB/Thunderbolt Ethernet.
    // Do not sum utun, bridge, awdl, llw, lo, vmenet, or peer-to-peer interfaces:
    // their counters can include the same traffic as the physical uplink.
    guard name.hasPrefix("en") else { return false }
    let suffix = name.dropFirst(2)
    return !suffix.isEmpty && suffix.allSatisfy({ $0.isASCII && $0.isNumber })
  }

  static func selectNetworkInterface(
    _ candidates: [SystemNetworkCounters], primary: String?, previous: String?
  ) -> SystemNetworkCounters? {
    let physical = candidates.filter { isPhysicalInterface($0.interface) }
    if let primary, let selected = physical.first(where: { $0.interface == primary }) { return selected }
    if let previous, let selected = physical.first(where: { $0.interface == previous }) { return selected }
    // With no physical default (for example a VPN default), pick one interface
    // and keep it stable rather than double-counting all active connections.
    return physical.max {
      let left = Double($0.received) + Double($0.sent)
      let right = Double($1.received) + Double($1.sent)
      return left == right ? $0.interface > $1.interface : left < right
    }
  }

  static func memoryUsage(
    total: UInt64, pageSize: UInt64, anonymousPages: UInt64, purgeablePages: UInt64,
    wiredPages: UInt64, compressedPages: UInt64, swapUsed: UInt64, pressure: MemoryPressure
  ) -> MemoryUsage? {
    guard total > 0, pageSize > 0 else { return nil }
    let appPages = anonymousPages - min(purgeablePages, anonymousPages)
    let (residentPages, pageOverflow) = appPages.addingReportingOverflow(wiredPages)
    let (usedPages, compressedOverflow) = residentPages.addingReportingOverflow(compressedPages)
    let (usedBytes, byteOverflow) = usedPages.multipliedReportingOverflow(by: pageSize)
    let (compressedBytes, compressionOverflow) = compressedPages.multipliedReportingOverflow(by: pageSize)
    guard !pageOverflow, !compressedOverflow, !byteOverflow, !compressionOverflow else { return nil }
    // Approximate Activity Monitor's “Memory Used”: resident anonymous/app memory
    // less purgeable pages, plus wired memory and the physical compressed store.
    // Reclaimable file-backed cache is excluded; compressed pages are counted once.
    return MemoryUsage(
      total: total, used: min(usedBytes, total), compressed: min(compressedBytes, total),
      swapUsed: swapUsed, pressure: pressure
    )
  }

  static func batteryStatus(
    current: Double, maximum: Double, isCharging: Bool, isPluggedIn: Bool, minutesRemaining: Int?
  ) -> BatteryStatus? {
    guard current.isFinite, maximum.isFinite, current >= 0, maximum > 0 else { return nil }
    return BatteryStatus(
      level: min(current / maximum, 1), isCharging: isCharging, isPluggedIn: isPluggedIn,
      minutesRemaining: minutesRemaining.flatMap { $0 >= 0 ? $0 : nil }
    )
  }
}

actor SystemMetricsReader {
  private var previousCPU: SystemCPUCounters?
  private var previousNetwork: SystemNetworkCounters?
  private var previousInstant: Double?
  private var cachedDisks: [DiskUsage] = []
  private var cachedSensors: HardwareSensorSnapshot?
  private var lastSensorInstant: Double?
  private var generation = 0

  func resetBaseline() {
    previousCPU = nil
    previousNetwork = nil
    previousInstant = nil
  }

  func suspend() {
    generation += 1
    resetBaseline()
    cachedDisks = []
    cachedSensors = nil
    lastSensorInstant = nil
  }

  func sample(options: SystemSamplingOptions) async -> SystemSnapshot {
    let currentGeneration = generation
    let applicationMemory = options.includeApplications ? await ApplicationMemoryReader.sample() : nil
    guard !Task.isCancelled, currentGeneration == generation else { return SystemSnapshot() }
    let instant = Self.monotonicSeconds()
    let interval = previousInstant.map { instant - $0 }
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    let cpuCounters = Self.readCPU(host: host)
    let networkCounters = Self.readNetwork(previous: previousNetwork?.interface)
    let cpu = SystemMetricMath.cpuUsage(previous: previousCPU, current: cpuCounters, interval: interval)
    let network = SystemMetricMath.networkUsage(previous: previousNetwork, current: networkCounters, interval: interval)
    // Failed reads invalidate the baseline too; a later success starts cleanly.
    previousCPU = cpuCounters
    previousNetwork = networkCounters
    previousInstant = instant
    if options.includeDisks { cachedDisks = Self.readDisks() }
    if options.includeSensors {
      if lastSensorInstant.map({ instant - $0 >= 5 }) ?? true {
        cachedSensors = HardwareSensorReader.read()
        lastSensorInstant = instant
      }
    } else {
      cachedSensors = nil
      lastSensorInstant = nil
    }
    return SystemSnapshot(
      sampledAt: .now, cpu: cpu, memory: Self.readMemory(host: host), applicationMemory: applicationMemory,
      sensors: cachedSensors, disks: cachedDisks,
      network: network, battery: Self.readBattery()
    )
  }

  private static func monotonicSeconds() -> Double {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    // Continuous Mach time includes sleep; wall-clock/date changes never alter rates.
    return Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
  }

  private static func readCPU(host: host_t) -> SystemCPUCounters? {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    return SystemCPUCounters(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
  }

  private static func readMemory(host: host_t) -> MemoryUsage? {
    var info = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }
    var pageSize: vm_size_t = 0
    var swap = xsw_usage()
    var swapSize = MemoryLayout<xsw_usage>.stride
    guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS,
      sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
    else { return nil }
    var pressureValue: Int32 = 0
    var pressureSize = MemoryLayout<Int32>.stride
    let pressureResult = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureValue, &pressureSize, nil, 0)
    let pressure: MemoryPressure
    switch pressureResult == 0 ? pressureValue : 0 {
    case 1: pressure = .normal
    case 2: pressure = .warning
    case 4: pressure = .critical
    default: pressure = .unknown
    }
    return SystemMetricMath.memoryUsage(
      total: ProcessInfo.processInfo.physicalMemory, pageSize: UInt64(pageSize),
      anonymousPages: UInt64(info.internal_page_count), purgeablePages: UInt64(info.purgeable_count),
      wiredPages: UInt64(info.wire_count), compressedPages: UInt64(info.compressor_page_count),
      swapUsed: swap.xsu_used, pressure: pressure
    )
  }

  private static func readNetwork(previous: String?) -> SystemNetworkCounters? {
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    let mibCount = u_int(mib.count)
    var length = 0
    guard sysctl(&mib, mibCount, nil, &length, nil, 0) == 0, length > 0 else { return nil }
    // Interfaces can change between the size query and the read. Retry once on ENOMEM.
    var buffer = Data(count: length)
    var result = buffer.withUnsafeMutableBytes { sysctl(&mib, mibCount, $0.baseAddress, &length, nil, 0) }
    if result != 0, errno == ENOMEM {
      guard sysctl(&mib, mibCount, nil, &length, nil, 0) == 0, length > 0 else { return nil }
      buffer = Data(count: length)
      result = buffer.withUnsafeMutableBytes { sysctl(&mib, mibCount, $0.baseAddress, &length, nil, 0) }
    }
    guard result == 0, length <= buffer.count else { return nil }
    let candidates: [SystemNetworkCounters] = buffer.withUnsafeBytes { raw in
      var candidates: [SystemNetworkCounters] = []
      var offset = 0
      while offset + 4 <= length {
        let messageLength = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
        guard messageLength >= 4, offset + messageLength <= length else { break }
        defer { offset += messageLength }
        guard raw[offset + 3] == UInt8(RTM_IFINFO2), messageLength >= MemoryLayout<if_msghdr2>.size else { continue }
        let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
        guard message.ifm_flags & Int32(IFF_UP) != 0, message.ifm_flags & Int32(IFF_RUNNING) != 0,
          message.ifm_flags & Int32(IFF_LOOPBACK) == 0
        else { continue }
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        guard if_indextoname(UInt32(message.ifm_index), &name) != nil else { continue }
        candidates.append(SystemNetworkCounters(
          interface: String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self),
          received: message.ifm_data.ifi_ibytes, sent: message.ifm_data.ifi_obytes
        ))
      }
      return candidates
    }
    return SystemMetricMath.selectNetworkInterface(candidates, primary: defaultInterface(), previous: previous)
  }

  private static func defaultInterface() -> String? {
    guard let store = SCDynamicStoreCreate(nil, "AugmaSystemMonitor" as CFString, nil, nil) else { return nil }
    for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
      if let state = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
        let name = state["PrimaryInterface"] as? String, SystemMetricMath.isPhysicalInterface(name)
      { return name }
    }
    return nil
  }

  private static func readDisks() -> [DiskUsage] {
    let keys: Set<URLResourceKey> = [
      .volumeNameKey, .volumeUUIDStringKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
      .volumeIsLocalKey, .volumeIsBrowsableKey, .isHiddenKey,
    ]
    let manager = FileManager.default
    let root = URL(filePath: "/", directoryHint: .isDirectory)
    let data = URL(filePath: "/System/Volumes/Data", directoryHint: .isDirectory)
    let startup = manager.fileExists(atPath: data.path) ? data : root
    let startupName = (try? root.resourceValues(forKeys: [.volumeNameKey]))?.volumeName
    let mounted = manager.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
    let session = DASessionCreate(nil)
    var seen: Set<String> = []
    var disks: [DiskUsage] = []
    for url in [startup] + mounted {
      let isStartup = url.path == startup.path
      guard isStartup || (url.path != "/" && !url.path.hasPrefix("/System/Volumes/") && !url.path.hasPrefix("/Library/Developer/CoreSimulator/")),
        let values = try? url.resourceValues(forKeys: keys), values.volumeIsLocal == true,
        isStartup || (values.volumeIsBrowsable != false && values.isHidden != true),
        let total = values.volumeTotalCapacity, total > 0,
        let available = values.volumeAvailableCapacity, available >= 0
      else { continue }
      if let session, let disk = DADiskCreateFromVolumePath(nil, session, url as CFURL),
        let description = DADiskCopyDescription(disk) as? [String: Any]
      {
        let model = description[kDADiskDescriptionDeviceModelKey as String] as? String ?? ""
        let transport = description[kDADiskDescriptionDeviceProtocolKey as String] as? String ?? ""
        if description[kDADiskDescriptionVolumeNetworkKey as String] as? Bool == true
          || model.localizedCaseInsensitiveContains("disk image")
          || transport.localizedCaseInsensitiveContains("disk image")
        { continue }
      }
      let id = values.volumeUUIDString ?? url.standardizedFileURL.path
      guard seen.insert(id).inserted else { continue }
      disks.append(DiskUsage(
        id: id, name: isStartup ? (startupName ?? values.volumeName ?? "Macintosh HD") : (values.volumeName ?? url.lastPathComponent),
        total: UInt64(total), available: min(UInt64(available), UInt64(total))
      ))
    }
    return disks
  }

  private static func readBattery() -> BatteryStatus? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
    else { return nil }
    for source in sources {
      guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
        description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
        description[kIOPSIsPresentKey] as? Bool == true,
        let current = description[kIOPSCurrentCapacityKey] as? NSNumber,
        let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
        let charging = description[kIOPSIsChargingKey] as? Bool,
        let state = description[kIOPSPowerSourceStateKey] as? String,
        state == kIOPSACPowerValue || state == kIOPSBatteryPowerValue
      else { continue }
      let pluggedIn = state == kIOPSACPowerValue
      let remainingKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
      let minutes = charging || !pluggedIn ? (description[remainingKey] as? NSNumber)?.intValue : nil
      return SystemMetricMath.batteryStatus(
        current: current.doubleValue, maximum: maximum.doubleValue,
        isCharging: charging, isPluggedIn: pluggedIn, minutesRemaining: minutes
      )
    }
    return nil
  }
}
