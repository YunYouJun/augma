import Foundation

struct InstalledApplication: Identifiable, Equatable, Sendable {
  let id: String // Bundle identifier, never the display name.
  let name: String
  let path: String
}

struct ApplicationBuilding: Identifiable, Codable, Equatable, Sendable {
  let id: String
  var applicationName: String
  var applicationPath: String
  var nickname: String = ""
  var slot: Int
  var fixed = false

  var title: String { nickname.isEmpty ? applicationName : nickname }
  static let capacity = 12
  static let columns = 4
  var position: SIMD3<Float> { [Float(slot % 4) * 2.4 - 3.6, 0, Float(slot / 4) * 2.5 - 2.5] }
}

enum ApplicationRunState: Equatable {
  case missing, stopped, running, frontmost
  var title: String {
    switch self {
    case .missing: String(localized: "找不到应用")
    case .stopped: String(localized: "未运行")
    case .running: String(localized: "运行中")
    case .frontmost: String(localized: "当前应用")
    }
  }
}

struct ApplicationDistrictDocument: Codable, Equatable {
  var version = 1
  var buildings: [ApplicationBuilding] = []

  func validated() throws -> Self {
    guard version == 1 else { throw ApplicationDistrictError.unsupportedVersion }
    guard buildings.count <= ApplicationBuilding.capacity,
          Set(buildings.map(\.id)).count == buildings.count,
          Set(buildings.map(\.slot)).count == buildings.count,
          buildings.allSatisfy({
            !$0.id.isEmpty && $0.id.count <= 255 && !$0.id.contains(where: { $0.isWhitespace || $0.isNewline }) &&
            !$0.applicationName.isEmpty && $0.applicationName.count <= 80 && $0.nickname.count <= 40 &&
            $0.applicationPath.hasPrefix("/") && $0.applicationPath.count <= 4096 &&
            URL(fileURLWithPath: $0.applicationPath).pathExtension.lowercased() == "app" &&
            (0..<ApplicationBuilding.capacity).contains($0.slot)
          }) else { throw ApplicationDistrictError.invalidLayout }
    return self
  }
}

enum ApplicationDistrictError: LocalizedError {
  case unsupportedVersion, invalidLayout, notApplication, missingApplication, activationFailed, full, fixedPosition, invalidName
  var errorDescription: String? {
    switch self {
    case .unsupportedVersion: String(localized: "此布局来自较新版本，原文件已保留。")
    case .invalidLayout: String(localized: "布局文件无效，原文件已保留。")
    case .notApplication: String(localized: "请选择具有有效标识的 macOS 应用。")
    case .missingApplication: String(localized: "找不到这个应用，请重新选择应用位置。")
    case .activationFailed: String(localized: "无法切换到应用，请稍后重试。")
    case .full: String(localized: "应用街区最多容纳 12 座大楼。")
    case .fixedPosition: String(localized: "此位置已固定，请先取消固定。")
    case .invalidName: String(localized: "名称最多 40 个字符，不能包含换行或控制字符。")
    }
  }
}
