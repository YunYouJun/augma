import Darwin
import Foundation
import IOKit

struct FanReading: Identifiable, Sendable {
  var id: Int
  var rpm: Double?
}

struct HardwareSensorSnapshot: Sendable {
  var sampledAt: Date = .now
  var cpuTemperature: Double?
  var cpuSensorCount: Int
  /// nil means unavailable; an empty array means the SMC reports no fans.
  var fans: [FanReading]?
}

/// Read-only AppleSMC packet ABI: 80 bytes on both supported Mac architectures.
/// The service/key protocol is undocumented by Apple and may be unavailable on a model.
/// Protocol references: exelban/stats SMC/smc.swift and Modules/Sensors/values.swift.
enum SMCReadCodec {
  static let packetSize = 80

  static func fourCC(_ string: String) -> UInt32? {
    guard string.utf8.count == 4 else { return nil }
    return string.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
  }

  static func request(key: String, command: UInt8, size: UInt32 = 0) -> [UInt8]? {
    // Only key metadata (9) and value reads (5) are implemented, never writes (6).
    guard let code = fourCC(key), command == 9 || command == 5, size <= 32 else { return nil }
    var bytes = [UInt8](repeating: 0, count: packetSize)
    for offset in 0..<4 {
      bytes[offset] = UInt8(truncatingIfNeeded: code >> (offset * 8))
      bytes[28 + offset] = UInt8(truncatingIfNeeded: size >> (offset * 8))
    }
    bytes[42] = command
    return bytes
  }

  static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    (0..<4).reduce(0) { $0 | (UInt32(bytes[offset + $1]) << ($1 * 8)) }
  }

  static func decode(type: UInt32, bytes: [UInt8]) -> Double? {
    let value: Double
    switch type {
    case fourCC("sp78") where bytes.count == 2:
      value = Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
    case fourCC("fpe2") where bytes.count == 2:
      value = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
    case fourCC("flt ") where bytes.count == 4:
      value = Double(Float(bitPattern: uint32(bytes, at: 0)))
    case fourCC("ui8 ") where bytes.count == 1: value = Double(bytes[0])
    case fourCC("ui16") where bytes.count == 2: value = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
    case fourCC("ui32") where bytes.count == 4:
      value = Double(bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
    default: return nil
    }
    return value.isFinite ? value : nil
  }

  static func validTemperature(_ value: Double) -> Bool {
    // Exclude non-readings and parked-core placeholders instead of averaging them in.
    value.isFinite && value > 15 && value < 125
  }

  static func cpuKeys(brand: String) -> [String] {
    if brand.contains("Apple M5") {
      return ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U",
              "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"]
    }
    if brand.contains("Apple M4") {
      return ["Te05", "Te0S", "Te09", "Te0H", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
    }
    if brand.contains("Apple M3") {
      return ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E",
              "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"]
    }
    if brand.contains("Apple M2") {
      return ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
    }
    if brand.contains("Apple M1") {
      return ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
    }
    if brand.contains("Intel") { return ["TC0D", "TC0F", "TCAD", "TC0E"] }
    return [] // Never use a different chip generation's undocumented key mapping.
  }
}

enum HardwareSensorReader {
  static func read() -> HardwareSensorSnapshot? {
    guard let session = SMCReadSession() else { return nil }
    // The session closes at the end of this read; no IOKit handle stays resident.
    let brand = cpuBrand()
    var temperatures = SMCReadCodec.cpuKeys(brand: brand).compactMap { session.value($0) }
      .filter(SMCReadCodec.validTemperature)
    if brand.contains("Intel"), let first = temperatures.first { temperatures = [first] }
    var fans: [FanReading]?
    if let count = session.value("FNum"), count >= 0, count <= 8, count.rounded() == count {
      fans = (0..<Int(count)).map { id in
        let rpm = session.value("F\(id)Ac").flatMap { (0...20_000).contains($0) ? $0 : nil }
        return FanReading(id: id, rpm: rpm)
      }
    }
    return HardwareSensorSnapshot(cpuTemperature: temperatures.isEmpty ? nil : temperatures.reduce(0, +) / Double(temperatures.count),
                                  cpuSensorCount: temperatures.count, fans: fans)
  }

  private static func cpuBrand() -> String {
    var size = 0
    guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0, size < 1024 else { return "" }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else { return "" }
    return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }
}

private final class SMCReadSession {
  private let connection: io_connect_t

  init?() {
    let device = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
    guard device != 0 else { return nil }
    defer { IOObjectRelease(device) }
    var connection: io_connect_t = 0
    guard IOServiceOpen(device, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
    self.connection = connection
  }

  deinit { IOServiceClose(connection) }

  func value(_ key: String) -> Double? {
    guard let request = SMCReadCodec.request(key: key, command: 9), let info = call(request) else { return nil }
    let size = SMCReadCodec.uint32(info, at: 28)
    let type = SMCReadCodec.uint32(info, at: 32)
    guard size > 0, size <= 32,
      let request = SMCReadCodec.request(key: key, command: 5, size: size), let response = call(request)
    else { return nil }
    return SMCReadCodec.decode(type: type, bytes: Array(response[48..<(48 + Int(size))]))
  }

  private func call(_ request: [UInt8]) -> [UInt8]? {
    var response = [UInt8](repeating: 0, count: SMCReadCodec.packetSize)
    var size = response.count
    let status = request.withUnsafeBytes { input in
      response.withUnsafeMutableBytes { output in
        IOConnectCallStructMethod(connection, 2, input.baseAddress, input.count, output.baseAddress, &size)
      }
    }
    guard status == KERN_SUCCESS, size == SMCReadCodec.packetSize, response[40] == 0 else { return nil }
    return response
  }
}
