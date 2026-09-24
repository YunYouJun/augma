import Foundation
import Security
import SwiftUI

enum DeepSeekSettings {
  static let enabledKey = "deepSeekEnabled"
  static var isReady: Bool {
    UserDefaults.standard.bool(forKey: enabledKey) && DeepSeekKeychain.load() != nil
  }
}

enum DeepSeekKeychain {
  private static let service = "cn.yunyoujun.augma.deepseek"
  private static let account = "api-key"

  private static var identity: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service,
     kSecAttrAccount as String: account]
  }

  static func load() -> String? {
    var query = identity
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func save(_ key: String) throws {
    let data = Data(key.utf8)
    let status = SecItemUpdate(identity as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = identity
      item[kSecValueData as String] = data
      try check(SecItemAdd(item as CFDictionary, nil))
    } else {
      try check(status)
    }
  }

  static func remove() throws {
    let status = SecItemDelete(identity as CFDictionary)
    if status != errSecItemNotFound { try check(status) }
  }

  private static func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else {
      throw KeychainFailure(status: status)
    }
  }

  private struct KeychainFailure: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "无法访问钥匙串（错误 \(status)）。" }
  }
}

struct DeepSeekSettingsView: View {
  @AppStorage(DeepSeekSettings.enabledKey) private var enabled = false
  @State private var newKey = ""
  @State private var hasKey = DeepSeekKeychain.load() != nil
  @State private var feedback = ""

  var body: some View {
    Form {
      Section("指令理解") {
        Toggle("使用 DeepSeek 理解未匹配的指令", isOn: $enabled)
          .disabled(!hasKey)
          .onChange(of: enabled) { _, _ in notifyChange() }
        Text("开启后，只有本地规则无法识别的指令文字会发送给 DeepSeek。云端只能选择演示版已有操作；API 调用可能产生费用。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("DeepSeek API Key") {
        SecureField(hasKey ? "输入新密钥以替换现有密钥" : "输入 API Key", text: $newKey)
          .onSubmit(saveKey)
        HStack {
          Button("保存密钥", action: saveKey)
            .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Button("删除密钥", action: removeKey)
            .disabled(!hasKey)
          Spacer()
          Text(hasKey ? "已保存在 macOS 钥匙串" : "未配置密钥")
            .foregroundStyle(.secondary)
        }
        if !feedback.isEmpty {
          Text(feedback).font(.caption)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .padding()
  }

  private func saveKey() {
    let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return }
    do {
      try DeepSeekKeychain.save(key)
      newKey = ""
      hasKey = true
      feedback = "密钥已保存。"
      notifyChange()
    } catch {
      feedback = error.localizedDescription
    }
  }

  private func removeKey() {
    do {
      try DeepSeekKeychain.remove()
      enabled = false
      hasKey = false
      feedback = "密钥已删除。"
      notifyChange()
    } catch {
      feedback = error.localizedDescription
    }
  }

  private func notifyChange() {
    NotificationCenter.default.post(name: .augmaDeepSeekConfigChanged, object: nil)
  }
}

extension Notification.Name {
  static let augmaDeepSeekConfigChanged = Notification.Name("cn.yunyoujun.augma.deepseek-config-changed")
}
